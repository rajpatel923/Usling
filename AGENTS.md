# AGENTS.md — Pair Companion

## Required reading before touching any code

1. **Product plan:** `ConnectMe/docs/main.md`
   - Vision, scope, release phases (V1 → V1.1 → V2), weekly milestones, privacy principles.

2. **Technical architecture:** `ConnectMe/docs/technical.md`
   - Authoritative stack, approved/prohibited technologies, module boundaries, event contracts, coding standards, privacy invariants.

## Current phase

**V1 Dot MVP** — Weeks 1–12. No AI, no Rive, no Redis, no WebRTC, no ScreenCaptureKit.

## Repo layout

```
ConnectMe/                    ← macOS Swift source (Xcode: ConnectMe.xcodeproj)
services/realtime-api/        ← TypeScript + Fastify backend
protocol/                     ← Shared event schemas and contract fixtures
infrastructure/               ← Docker Compose, deployment, monitoring
docs/adr/                     ← Architecture Decision Records
scripts/                      ← Build and release helpers
devlog/                       ← Compressed session knowledge log
```

## Hard rules

- The shared couples data plane must never contain screenshots, window titles, app names, AI prompts, or AI responses.
- V2 AI features are out of scope until the V1.1 gate passes.
- Every new dependency requires an ADR and user approval.
