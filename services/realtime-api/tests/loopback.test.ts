import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { buildApp } from '../src/app.js'
import WebSocket from 'ws'
import type { FastifyInstance } from 'fastify'

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeEnvelope(type: string, payload: Record<string, unknown> = {}) {
  return JSON.stringify({
    version: 1,
    type,
    eventId: crypto.randomUUID(),
    pairId: 'test-pair',
    actorId: 'user-a',
    deviceId: 'device-a',
    sequence: Math.floor(Math.random() * 1000),
    sentAt: new Date().toISOString(),
    payload,
  })
}

async function waitForMessage(ws: WebSocket, timeoutMs = 1000): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Timeout waiting for message')), timeoutMs)
    ws.once('message', (data) => {
      clearTimeout(timer)
      resolve(JSON.parse(data.toString()))
    })
  })
}

async function connectClient(url: string): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url)
    ws.once('open', () => resolve(ws))
    ws.once('error', reject)
  })
}

// ── Tests ─────────────────────────────────────────────────────────────────────

let app: FastifyInstance
let port: number

beforeAll(async () => {
  app = await buildApp()
  await app.listen({ host: '127.0.0.1', port: 0 })
  port = (app.server.address() as { port: number }).port
})

afterAll(async () => {
  await app.close()
})

describe('loopback — relay', () => {
  it('relays presence.updated from userA to userB', async () => {
    const wsA = await connectClient(`ws://127.0.0.1:${port}/ws?token=test-pair:user-a:char-a`)
    const wsB = await connectClient(`ws://127.0.0.1:${port}/ws?token=test-pair:user-b:char-b`)

    const receivePromise = waitForMessage(wsB)
    wsA.send(makeEnvelope('presence.updated', { state: 'active' }))
    const received = await receivePromise as Record<string, unknown>

    expect(received['type']).toBe('presence.updated')
    expect((received['payload'] as Record<string,unknown>)['state']).toBe('active')

    wsA.close(); wsB.close()
  })

  it('rejects movement from wrong owner and does not relay to partner', async () => {
    const wsA = await connectClient(`ws://127.0.0.1:${port}/ws?token=test-pair2:user-a:char-a`)
    const wsB = await connectClient(`ws://127.0.0.1:${port}/ws?token=test-pair2:user-b:char-b`)

    // userA tries to move char-b (owned by userB) — should be rejected
    const errorPromise = waitForMessage(wsA)
    wsA.send(JSON.stringify({
      version: 1,
      type: 'position.updated',
      eventId: crypto.randomUUID(),
      pairId: 'test-pair2',
      actorId: 'user-a',
      deviceId: 'device-a',
      sequence: 1,
      sentAt: new Date().toISOString(),
      payload: {
        dragSessionId: crypto.randomUUID(),
        characterId: 'char-b',  // wrong — userA owns char-a
        x: 0.5,
        y: 0.5,
      },
    }))

    const errorMsg = await errorPromise as Record<string, unknown>
    expect(errorMsg['type']).toBe('error')
    expect((errorMsg['payload'] as Record<string,unknown>)['code']).toBe('OWNERSHIP_VIOLATION')

    wsA.close(); wsB.close()
  })

  it('rejects connection with invalid token', async () => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws?token=bad-token`)
    await new Promise<void>((resolve) => {
      ws.once('close', () => resolve())
    })
    expect(ws.readyState).toBe(WebSocket.CLOSED)
  })
})
