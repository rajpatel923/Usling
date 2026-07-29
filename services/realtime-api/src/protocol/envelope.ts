import { z } from 'zod'

export const CURRENT_VERSION = 1 as const

export const BaseEnvelopeSchema = z.object({
  version: z.literal(CURRENT_VERSION),
  type: z.string().min(1),
  eventId: z.string().uuid(),
  pairId: z.string().min(1),
  actorId: z.string().min(1),
  deviceId: z.string().min(1),
  sequence: z.number().int().nonnegative(),
  sentAt: z.string().datetime(),
  payload: z.record(z.string(), z.unknown()).default({}),
})

export type BaseEnvelope = z.infer<typeof BaseEnvelopeSchema>

export type ParseResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: string; details?: unknown }

export function parseEnvelope(raw: unknown): ParseResult<BaseEnvelope> {
  const result = BaseEnvelopeSchema.safeParse(raw)
  if (!result.success) {
    return { ok: false, error: 'INVALID_ENVELOPE', details: result.error.format() }
  }
  return { ok: true, data: result.data }
}
