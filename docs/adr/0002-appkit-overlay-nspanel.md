# ADR-0002: AppKit overlay using NSPanel

## Status
Accepted

## Context
The floating companion window must be transparent, non-activating, click-through outside the character, visible across all Spaces, and compatible with full-screen apps.

## Decision
Implement the overlay as an AppKit NSPanel (or appropriate NSWindow subclass) hosting SwiftUI content where useful.

## Alternatives considered
- Pure SwiftUI window: `.windowStyle`, `.windowLevel`, and collection behavior APIs do not provide the necessary low-level control.

## Consequences
- Overlay behavior is correct and testable across macOS Spaces/full-screen scenarios.
- AppKit adapter code must be kept small; rendering logic stays in SwiftUI/Core Animation.

## Privacy and security effect
None.

## Migration plan
Not applicable for V1.

## Approval
Initial architecture — July 29, 2026.
