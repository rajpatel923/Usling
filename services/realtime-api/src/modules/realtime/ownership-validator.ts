import type { BaseEnvelope } from '../../protocol/envelope.js'
import type { ConnectionMeta } from './connection-registry.js'

/** Event types where the actor must own the named character. */
const OWNERSHIP_REQUIRED_TYPES = new Set([
  'drag.started',
  'position.updated',
  'drag.ended',
])

/**
 * Validates that the sender owns the character referenced in the event payload.
 * Returns true if the event is allowed to proceed.
 */
export function validateOwnership(envelope: BaseEnvelope, conn: ConnectionMeta): boolean {
  if (!OWNERSHIP_REQUIRED_TYPES.has(envelope.type)) return true

  const payload = envelope.payload as Record<string, unknown>
  const characterId = payload['characterId']

  if (typeof characterId !== 'string') return false

  return characterId === conn.characterId
}
