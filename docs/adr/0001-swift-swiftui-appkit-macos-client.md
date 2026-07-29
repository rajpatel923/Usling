# ADR-0001: Native macOS client — Swift with SwiftUI and AppKit

## Status
Accepted

## Context
The product requires a transparent floating overlay window, click-through hit testing, full-screen and Spaces support, sleep/wake/lock signals, Keychain storage, and signed notarized distribution. These are deeply native macOS concerns.

## Decision
Use Swift with SwiftUI and AppKit. SwiftUI handles regular UI surfaces (onboarding, settings, emote picker). AppKit handles the overlay window (NSPanel), window level, Spaces collection, and non-activating behavior.

## Alternatives considered
- Electron: adds a bridge layer around native work without removing it; higher memory overhead.
- Flutter macOS: same problem — native overlay still requires Swift adapters.
- React Native macOS: same problem.
- Pure SwiftUI window: insufficient low-level control for overlay behavior.

## Consequences
- Best-fit for all native macOS requirements.
- Team must be comfortable with both SwiftUI and AppKit.
- AppKit adapters should be thin; business logic stays in domain layer.

## Privacy and security effect
None — this is a client platform choice.

## Migration plan
Not applicable for V1.

## Approval
Initial architecture — July 29, 2026.
