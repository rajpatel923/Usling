# ADR-0006: Native Swift animation for V1; Rive evaluated in V1.1

## Status
Accepted

## Context
V1 uses a simple animated dot as a placeholder for the final character. The interaction model and behavior must be validated before investing in final animation tooling.

## Decision
Use native SwiftUI animation and Core Animation for V1. Evaluate Rive vs. sprite sheets in Week 13 (V1.1 spike) before committing to a character animation runtime.

## Alternatives considered
- Rive from the start: adds a dependency and a state-machine design tool before the interaction model is stable.
- Sprite sheets from the start: same problem.

## Consequences
- V1 has zero animation framework dependencies.
- The dot renderer becomes the fallback and debug implementation when Rive is adopted.
- Animation state contract (presence states, emote IDs) must be defined independently of the rendering technology.

## Privacy and security effect
None.

## Migration plan
Week 13 spike compares Rive and sprite sheets on CPU, memory, package size, workflow, and accessibility. The winner is adopted for V1.1. The dot renderer is retained as fallback.

## Approval
Initial architecture — July 29, 2026.
