# Protocol — Event Envelope Specification

All WebSocket events use a common JSON envelope:

```json
{
  "version": 1,
  "type": "presence.updated",
  "eventId": "opaque-unique-id",
  "pairId": "opaque-pair-id",
  "actorId": "opaque-user-id",
  "deviceId": "opaque-device-id",
  "sequence": 42,
  "sentAt": "2026-07-29T20:00:00Z",
  "payload": {}
}
```

## Rules

- `eventId` — deduplication key.
- `pairId` — authorized server-side; never trusted from client.
- `actorId` — derived from authentication.
- `sequence` — monotonically increasing per stream; stale packets discarded.
- `sentAt` — used for expiry and ordering only; never shown to partner as a timestamp.
- Unknown `version` values and unsupported `type` values must fail safely.

## Approved V1 event types

| type | direction | durable |
|---|---|---|
| `session.ready` | server → client | no |
| `heartbeat` | client → server | no |
| `presence.updated` | bidirectional relay | current state only |
| `display.geometry` | bidirectional relay | session only |
| `drag.started` | bidirectional relay | no |
| `position.updated` | bidirectional relay | no |
| `drag.ended` | bidirectional relay | final state optional |
| `emote.sent` | bidirectional relay | short TTL |
| `emote.delivered` | bidirectional relay | short TTL |
| `emote.deferred` | bidirectional relay | short TTL |
| `emote.acknowledged` | bidirectional relay | session only |
| `emote.expired` | server → sender | no |
| `pair.revoked` | server → clients | pair record updated |
| `error` | server → client | no |

## Directories

- `schemas/` — JSON Schema or Zod-compatible schema files per event type.
- `fixtures/valid/` — Valid event examples consumed by both Swift and TypeScript tests.
- `fixtures/invalid/` — Invalid event examples that must be rejected.
