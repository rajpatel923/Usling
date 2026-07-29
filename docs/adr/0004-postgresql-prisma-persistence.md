# ADR-0004: PostgreSQL + Prisma for durable data

## Status
Accepted

## Context
Durable data includes users, devices, pair relationships, invite codes, sessions, and roaming preferences. The schema is relational and benefits from typed migrations and explicit constraints (e.g., exactly two members per pair, one-time invite codes).

## Decision
Use PostgreSQL with Prisma ORM for all durable server-side storage.

## Alternatives considered
- SQLite: not suitable for a multi-client server workload.
- MongoDB: document model adds no benefit for a well-defined relational schema.
- Supabase: hides migration control.

## Consequences
- Typed TypeScript client generated from schema.
- Migrations are explicit and reviewable.
- Docker Compose spins up local PostgreSQL for development.

## Privacy and security effect
Schema enforces no-history defaults. Prohibited data types (presence history, screenshots, app names) must not appear as Prisma models. Any addition requires a privacy review.

## Migration plan
All schema changes use Prisma migrations. No manual production schema edits.

## Approval
Initial architecture — July 29, 2026.
