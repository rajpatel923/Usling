import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { messageService } from './message.service.js'
import { pairingService } from '../pairing/pairing.service.js'
import { registry } from '../realtime/connection-registry.js'
import { config } from '../../config/index.js'

const SendBody = z.object({
  content: z.string().min(1).max(140),
})

const dbReady = () =>
  config.DATABASE_URL?.includes('.pooler.supabase.com') ||
  config.DATABASE_URL?.includes('localhost')

export async function registerMessageRoutes(app: FastifyInstance) {
  app.post('/messages', { preHandler: [app.authenticate] }, async (req, reply) => {
    const body = SendBody.safeParse(req.body)
    if (!body.success) {
      return reply.code(400).send({ error: 'content must be 1–140 characters' })
    }

    const { id: senderId } = req.authUser
    const content = body.data.content
    const now = new Date()

    // ── Dev bypass: relay via WebSocket only when DB is not configured ──
    if (!dbReady()) {
      const pairId = 'dev-pair-1'
      const messageId = crypto.randomUUID()
      const partnerSockets = registry.getPartnerSockets(pairId, senderId)
      const envelope = JSON.stringify({
        version: 1, type: 'message.sent',
        eventId: messageId, pairId, actorId: senderId,
        deviceId: 'server', sequence: 0, sentAt: now.toISOString(),
        payload: { messageId, content, sentAt: now.toISOString() },
      })
      for (const socket of partnerSockets) {
        if (socket.readyState === socket.OPEN) socket.send(envelope)
      }
      return reply.code(201).send({ messageId })
    }

    // ── Production path: store in DB then push ──
    const pairId = await pairingService.getPairId(senderId)
    if (!pairId) return reply.code(403).send({ error: 'Not paired' })

    const message = await messageService.send(senderId, pairId, content)
    const partnerSockets = registry.getPartnerSockets(pairId, senderId)
    const envelope = JSON.stringify({
      version: 1, type: 'message.sent',
      eventId: message.id, pairId, actorId: senderId,
      deviceId: 'server', sequence: 0, sentAt: message.createdAt.toISOString(),
      payload: { messageId: message.id, content: message.content, sentAt: message.createdAt.toISOString() },
    })
    for (const socket of partnerSockets) {
      if (socket.readyState === socket.OPEN) socket.send(envelope)
    }

    return reply.code(201).send({ messageId: message.id })
  })
}
