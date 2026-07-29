# ADR-0005: Native WebSocket with JSON event envelopes

## Status
Accepted

## Context
The product needs low-latency bidirectional events for presence, gestures, position updates, heartbeats, and pair revocation. Peer-to-peer audio or video is not required.

## Decision
Use secure standard WebSockets (wss://) with JSON event envelopes during V1 and V1.1. Do not use WebRTC or Socket.IO.

## Alternatives considered
- WebRTC: unnecessary NAT/peer-to-peer complexity; a server relay is simpler for auth, ownership, rate limiting, and reconnect.
- Socket.IO: additional protocol layer over WebSocket; native WebSocket keeps the Swift client simpler and the event protocol explicit.
- Protocol Buffers / MessagePack: premature optimization; JSON is inspectable and sufficient at expected payload volume.

## Consequences
- Events are easy to inspect and test with plain text fixtures.
- Protocol bugs are easier to diagnose.
- Swift client uses URLSessionWebSocketTask directly.

## Privacy and security effect
JSON payloads make it easier to audit that forbidden fields are absent from partner-bound events.

## Migration plan
Move to binary encoding only with measurements and an ADR.

## Approval
Initial architecture — July 29, 2026.
