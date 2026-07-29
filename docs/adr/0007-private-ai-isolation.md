# ADR-0007: Private AI isolation from couples data plane

## Status
Accepted

## Context
V2 introduces an optional screen-aware AI assistant. If AI observations could enter partner-visible events, the product would become a surveillance tool and destroy user trust.

## Decision
V2 AI context is private and cannot directly enter partner-bound events. The AI module lives at /v1/private-ai/* and must not import the couples realtime event publisher. Sharing an AI result requires: AI answers → user opens compose screen → edits content → explicitly confirms send → a normal shared event is created (no private metadata).

## Alternatives considered
- Allowing AI summaries to automatically update presence state: rejected; creates surveillance risk.
- A separate app for AI: not required; isolation is maintained within one app through hard data-plane separation.

## Consequences
- AI features can be added (V2) without weakening the couples trust model.
- Automated tests must enforce that AI payload cannot enter shared event schemas.
- V1 and V1.1 must remain fully functional without any AI permission.

## Privacy and security effect
This is the central privacy decision of the V2 architecture. Screen capture is explicit-invocation-only; no continuous screenshot timer is permitted; screenshots are not stored by default.

## Migration plan
Not applicable — this is a design constraint, not a changeable choice.

## Approval
Initial architecture — July 29, 2026.
