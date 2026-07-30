import { z } from 'zod'
import { BaseEnvelopeSchema, type ParseResult } from './envelope.js'

// ── Payload schemas ───────────────────────────────────────────────────────────

const CoarsePresenceState = z.enum(['active', 'away', 'sleeping', 'unavailable'])

const payloads = {
  'session.ready': z.object({ pairId: z.string() }),

  'heartbeat': z.object({}),

  'presence.updated': z.object({
    state: CoarsePresenceState,
  }),

  'display.geometry': z.object({
    displayToken: z.string(),   // rotating non-identifying session token
    width: z.number().positive(),
    height: z.number().positive(),
    scaleFactor: z.number().positive(),
    isPrimary: z.boolean(),
  }),

  'drag.started': z.object({
    characterId: z.string(),
    dragSessionId: z.string().uuid(),
    targetDisplayToken: z.string(),
  }),

  'position.updated': z.object({
    dragSessionId: z.string().uuid(),
    characterId: z.string(),
    x: z.number().min(0).max(1),
    y: z.number().min(0).max(1),
  }),

  'drag.ended': z.object({
    dragSessionId: z.string().uuid(),
    characterId: z.string(),
    finalX: z.number().min(0).max(1),
    finalY: z.number().min(0).max(1),
  }),

  'emote.sent': z.object({
    gestureId: z.string(),
    requestId: z.string().uuid(),
    ttlSeconds: z.number().int().positive(),
  }),

  'emote.delivered': z.object({
    requestId: z.string().uuid(),
  }),

  'emote.deferred': z.object({
    requestId: z.string().uuid(),
    reason: z.enum(['focus', 'snooze', 'quiet_hours']),
  }),

  'emote.acknowledged': z.object({
    requestId: z.string().uuid(),
    reaction: z.string().optional(),
  }),

  'emote.expired': z.object({
    requestId: z.string().uuid(),
  }),

  'pair.revoked': z.object({
    reasonCategory: z.enum(['unpaired', 'blocked', 'admin']),
  }),

  'error': z.object({
    code: z.string(),
    message: z.string(),
  }),
} as const

export type EventType = keyof typeof payloads

export const APPROVED_EVENT_TYPES = Object.keys(payloads) as EventType[]

// ── Discriminated union ───────────────────────────────────────────────────────

type TypedEvent<T extends EventType> = z.infer<typeof BaseEnvelopeSchema> & {
  type: T
  payload: z.infer<(typeof payloads)[T]>
}

export type AnyTypedEvent = { [T in EventType]: TypedEvent<T> }[EventType]

// ── Parser ────────────────────────────────────────────────────────────────────

export function parseEvent(raw: unknown): ParseResult<AnyTypedEvent> {
  // Step 1: validate envelope
  const base = BaseEnvelopeSchema.safeParse(raw)
  if (!base.success) {
    return { ok: false, error: 'INVALID_ENVELOPE', details: base.error.format() }
  }

  const { type, payload } = base.data

  // Step 2: reject unknown event types
  if (!(type in payloads)) {
    return { ok: false, error: 'UNKNOWN_EVENT_TYPE' }
  }

  // Step 3: validate type-specific payload
  const payloadSchema = payloads[type as EventType]
  const payloadResult = payloadSchema.safeParse(payload)
  if (!payloadResult.success) {
    return { ok: false, error: 'INVALID_PAYLOAD', details: payloadResult.error.format() }
  }

  return { ok: true, data: { ...base.data, type, payload: payloadResult.data } as AnyTypedEvent }
}
