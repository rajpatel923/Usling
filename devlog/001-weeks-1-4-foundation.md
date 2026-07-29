# [001] Weeks 1–4 foundation — overlay, dots, presence engine, backend relay
Date: 2026-07-29  Phase: V1  Week: 1–4

## What
Built the complete Weeks 1–4 implementation: macOS transparent overlay with two animated dots, local presence state machine, and TypeScript Fastify WebSocket relay with Zod event validation, loopback tests, and ownership enforcement.

## Why
These four milestones are the structural foundation of V1 Dot MVP. Everything else (pairing, gestures, positioning) sits on top of the overlay + presence engine + relay established here.

## Key decisions
- **PBXFileSystemSynchronizedRootGroup** (Xcode 15+): all Swift files in `ConnectMe/ConnectMe/` auto-compile — no pbxproj edits needed. `.gitkeep` files inside the source dir had to be removed (they were bundled as resources).
- **NSApplicationActivationPolicy.accessory**: app lives in menu bar only, no dock icon, no activating window.
- **ignoresMouseEvents = true** on the panel globally — panel is pass-through by default. DragGesture on the owned dot works because SwiftUI's hit-testing is handled inside the NSHostingView, not at the NSPanel level.
- **CGEventSource.secondsSinceLastEventType** for idle detection: zero permissions, accurate, polls on 30 s timer.
- **DistributedNotificationCenter** for screen lock/unlock (`com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`): no permission needed, fires reliably.
- **PresenceEngine** uses `@Observable + @MainActor` with structured concurrency; `AsyncStream<SensorEvent>` from the sensor monitor makes the engine trivially testable via mock streams.
- **Dev-mode token** for Week 4: `"pairId:userId:characterId"` query param. Replaced in Week 5 with real JWT.
- Backend connection registry is in-memory Map — Redis deferred until horizontal scaling is demonstrated to be needed.
- Loopback tests spin up a real Fastify server on a random port — no mocking, tests actual relay and ownership logic.

## Files touched (macOS)
```
App/ConnectMeApp.swift             — @main, AppDelegate, PresenceEngine injection
App/StatusBarController.swift      — NSStatusItem menu bar
Domain/Models/PresenceState.swift
Domain/Models/CharacterOwnership.swift
Domain/Models/NormalizedPosition.swift
Platform/OverlayWindow/CompanionPanel.swift  — NSPanel, transparent, floating, all Spaces
Platform/SystemSensors/SystemSensorMonitor.swift — NSWorkspace + idle polling
Features/Presence/PresenceEngine.swift  — state machine with hysteresis
Features/Overlay/OverlayCoordinator.swift
Features/Overlay/OverlayHostView.swift  — SwiftUI host with drag + two dots
Rendering/DotRenderer/DotView.swift
Rendering/DotRenderer/DotAnimationState.swift
ContentView.swift                  — stripped to OverlayHostView() wrapper
```

## Files touched (backend)
```
services/realtime-api/
  package.json, tsconfig.json, vitest.config.ts, .env.example
  src/config/index.ts
  src/protocol/envelope.ts          — BaseEnvelope Zod schema + parseEnvelope
  src/protocol/events.ts            — 14 approved event types + parseEvent
  src/modules/health/health.routes.ts
  src/modules/realtime/connection-registry.ts
  src/modules/realtime/ownership-validator.ts
  src/modules/realtime/realtime.handler.ts
  src/app.ts, src/server.ts
  prisma/schema.prisma               — stubs (User, Device, Pair, PairMember, Invite, Session)
  tests/protocol.test.ts             — 12 tests
  tests/loopback.test.ts             — 3 integration tests
protocol/fixtures/valid/           — 4 fixture files
protocol/fixtures/invalid/         — 3 fixture files
```

## Test results
- Backend: 15/15 pass (protocol + loopback)
- macOS: BUILD SUCCEEDED (xcodebuild, no code errors, one deployment-target range warning from project settings — macOS 27.0 is newer than xcode26 toolchain's stated range)

## Next
Week 5: Authentication + pairing (Sign in with Apple or dev-mode email, Keychain device key storage, short-lived invite codes, pair creation, unpair + token revocation).
