# ADR-0003: TypeScript + Fastify + @fastify/websocket backend

## Status
Accepted

## Context
The backend is a small realtime coordination service: HTTP auth endpoints, WebSocket relay, pair ownership enforcement, rate limiting, heartbeat tracking, and PostgreSQL access.

## Decision
Use TypeScript with Fastify and @fastify/websocket (native WebSockets, not Socket.IO).

## Alternatives considered
- NestJS: valid for a larger team, but adds module/DI/decorator overhead that hides connection behavior. Revisit if backend grows significantly.
- Vapor (Swift): single-language option; rejected to keep macOS and backend teams independent.
- Firebase/Supabase realtime: hides protocol behavior the project intends to own and control.

## Consequences
- Lightweight, typed, easy to learn.
- Route and WebSocket behavior remain visible and debuggable.
- No microservice split required for V1.

## Privacy and security effect
None — architectural choice. Security is enforced by pair authorization and schema validation layers regardless of framework.

## Migration plan
Move to NestJS only if the team grows and the module/DI structure solves an observed problem.

## Approval
Initial architecture — July 29, 2026.
