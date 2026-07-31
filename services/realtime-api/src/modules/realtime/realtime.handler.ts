import type { FastifyInstance } from 'fastify'
import type { WebSocket } from '@fastify/websocket'
import { parseEvent } from '../../protocol/events.js'
import { ConnectionRegistry, registry } from './connection-registry.js'
import { validateOwnership } from './ownership-validator.js'
import { pairingService } from '../pairing/pairing.service.js'
import { messageService } from '../messages/message.service.js'
import { config } from '../../config/index.js'
// registry is a shared singleton imported from connection-registry.ts

// Heartbeat interval and missed-pong threshold
const PING_INTERVAL_MS = 30_000
const MAX_MISSED_PINGS = 3

function sendJson(socket: WebSocket, obj: unknown) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify(obj))
  }
}

function sendError(socket: WebSocket, code: string, message: string) {
  sendJson(socket, { version: 1, type: 'error', payload: { code, message } })
}

export async function registerRealtimeRoutes(app: FastifyInstance) {
  app.get('/ws', { websocket: true, preHandler: [app.authenticate] }, async (socket, request) => {
    const { id: userId } = request.authUser

    // ── Pair lookup ─────────────────────────────────────────────────────
    let pairId: string | null = null

    // Dev bypass: accept ?devPairId= to skip DB when DATABASE_URL is not set
    const devPairId = (request.query as Record<string, string>)['devPairId']
    if (config.APP_ENV === 'development' && devPairId) {
      pairId = devPairId
    } else {
      pairId = await pairingService.getPairId(userId)
    }

    if (!pairId) {
      sendError(socket, 'NOT_PAIRED', 'Accept an invite before connecting')
      socket.close(1008, 'Not paired')
      return
    }

    const conn = { pairId, userId, characterId: userId, socket }
    registry.register(conn)
    app.log.info({ pairId, userId }, 'ws:connected')
    sendJson(socket, { version: 1, type: 'session.ready', payload: { pairId } })

    // Deliver any messages that arrived while the user was offline
    if (config.DATABASE_URL?.includes('.pooler.supabase.com') || config.DATABASE_URL?.includes('localhost')) {
      const pending = await messageService.getPendingFor(userId, pairId).catch(() => [])
      for (const msg of pending) {
        sendJson(socket, {
          version: 1, type: 'message.sent',
          eventId: msg.id, pairId, actorId: msg.senderId,
          deviceId: 'server', sequence: 0, sentAt: msg.createdAt.toISOString(),
          payload: { messageId: msg.id, content: msg.content, sentAt: msg.createdAt.toISOString() },
        })
      }
    }

    attachHandlers(socket, conn, app)
  })
}

interface ConnMeta {
  pairId: string
  userId: string
  characterId: string
  socket: WebSocket
}

function attachHandlers(socket: WebSocket, conn: ConnMeta, app: FastifyInstance) {
  let missedPings = 0

  // ── Heartbeat (protocol-level ping) ─────────────────────────────────
  const pingTimer = setInterval(() => {
    if (socket.readyState !== socket.OPEN) {
      clearInterval(pingTimer)
      return
    }
    missedPings++
    if (missedPings > MAX_MISSED_PINGS) {
      app.log.warn({ userId: conn.userId }, 'ws:ping_timeout')
      clearInterval(pingTimer)
      socket.close(1001, 'Ping timeout')
      return
    }
    socket.ping()
  }, PING_INTERVAL_MS)

  socket.on('pong', () => { missedPings = 0 })

  // ── Messages ─────────────────────────────────────────────────────────
  socket.on('message', (raw) => {
    let parsed: unknown
    try {
      parsed = JSON.parse(raw.toString())
    } catch {
      sendError(socket, 'INVALID_JSON', 'Message must be valid JSON')
      return
    }

    const result = parseEvent(parsed)
    if (!result.ok) {
      app.log.warn({ error: result.error }, 'ws:parse_error')
      sendError(socket, result.error, 'Event validation failed')
      return
    }

    const envelope = result.data

    // Drop heartbeats — they're handled at the transport level
    if (envelope.type === 'heartbeat') return

    // message.ack: recipient confirms receipt — delete from DB
    if (envelope.type === 'message.ack') {
      const { messageId } = (envelope as { payload: { messageId: string } }).payload
      void messageService.deleteOnAck(messageId, conn.userId).catch(() => {})
      return
    }

    if (!validateOwnership(envelope, conn)) {
      app.log.warn({ type: envelope.type, userId: conn.userId }, 'ws:ownership_violation')
      sendError(socket, 'OWNERSHIP_VIOLATION', 'You do not own that character')
      return
    }

    const partnerSockets = registry.getPartnerSockets(conn.pairId, conn.userId)
    const outgoing = JSON.stringify(parsed)
    for (const partnerSocket of partnerSockets) {
      if (partnerSocket.readyState === partnerSocket.OPEN) {
        partnerSocket.send(outgoing)
      }
    }

    app.log.debug({ type: envelope.type, relayed: partnerSockets.length }, 'ws:relayed')
  })

  // ── Cleanup ──────────────────────────────────────────────────────────
  socket.on('close', () => {
    clearInterval(pingTimer)
    registry.unregister(socket)
    app.log.info({ userId: conn.userId }, 'ws:disconnected')
  })

  socket.on('error', (err) => {
    clearInterval(pingTimer)
    app.log.error({ err, userId: conn.userId }, 'ws:error')
    registry.unregister(socket)
  })
}
