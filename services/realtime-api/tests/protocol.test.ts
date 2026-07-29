import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseEvent } from '../src/protocol/events.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const fixturesRoot = join(__dirname, '../../../protocol/fixtures')

function loadFixtures(dir: string) {
  return readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .map((f) => ({
      name: f,
      data: JSON.parse(readFileSync(join(dir, f), 'utf-8')),
    }))
}

describe('protocol — valid fixtures', () => {
  const valid = loadFixtures(join(fixturesRoot, 'valid'))
  for (const { name, data } of valid) {
    it(`accepts ${name}`, () => {
      const result = parseEvent(data)
      expect(result.ok, `Expected ok but got error: ${!result.ok ? (result as {error:string}).error : ''}`).toBe(true)
    })
  }
})

describe('protocol — invalid fixtures', () => {
  const invalid = loadFixtures(join(fixturesRoot, 'invalid'))
  for (const { name, data } of invalid) {
    it(`rejects ${name}`, () => {
      const result = parseEvent(data)
      expect(result.ok).toBe(false)
    })
  }
})

describe('protocol — edge cases', () => {
  it('rejects null', () => {
    expect(parseEvent(null).ok).toBe(false)
  })

  it('rejects empty object', () => {
    expect(parseEvent({}).ok).toBe(false)
  })

  it('rejects version 2 (not approved)', () => {
    const event = {
      version: 2,
      type: 'heartbeat',
      eventId: '550e8400-e29b-41d4-a716-446655440000',
      pairId: 'p1', actorId: 'u1', deviceId: 'd1', sequence: 1,
      sentAt: '2026-07-29T20:00:00Z', payload: {},
    }
    expect(parseEvent(event).ok).toBe(false)
  })

  it('rejects position.updated with x > 1', () => {
    const event = {
      version: 1,
      type: 'position.updated',
      eventId: '550e8400-e29b-41d4-a716-446655440000',
      pairId: 'p1', actorId: 'u1', deviceId: 'd1', sequence: 1,
      sentAt: '2026-07-29T20:00:00Z',
      payload: { dragSessionId: '550e8400-e29b-41d4-a716-446655440000', characterId: 'c1', x: 1.5, y: 0.5 },
    }
    expect(parseEvent(event).ok).toBe(false)
  })

  it('rejects unknown type without throwing', () => {
    const event = {
      version: 1,
      type: 'not.real',
      eventId: '550e8400-e29b-41d4-a716-446655440000',
      pairId: 'p1', actorId: 'u1', deviceId: 'd1', sequence: 1,
      sentAt: '2026-07-29T20:00:00Z', payload: {},
    }
    const result = parseEvent(event)
    expect(result.ok).toBe(false)
    expect((result as { error: string }).error).toBe('UNKNOWN_EVENT_TYPE')
  })
})
