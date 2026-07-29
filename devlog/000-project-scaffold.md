# [000] Initial project scaffold
Date: 2026-07-29  Phase: V1  Week: 0

## What
Created the complete monorepo folder structure for Pair Companion from a blank Xcode project. No Swift or TypeScript logic was written — directories and named placeholder/config files only.

## Why
The technical spec (docs/technical.md) defines the target repo layout. Establishing it early ensures all future work lands in the correct location, prevents ad-hoc sprawl, and gives AI agents a navigable structure to work within.

## Key decisions
- Repo root is `/ConnectMe/` (where ConnectMe.xcodeproj lives); macOS source is the nested `ConnectMe/ConnectMe/` folder matching Xcode conventions.
- `ContentView.swift` left untouched — Xcode project file not modified in this step. Xcode source groups will be wired when Swift files are added in Week 1.
- `infrastructure/compose.yaml` created with PostgreSQL only; Redis section is commented out per ADR-0004 (defer until horizontal scaling is needed).
- Seven initial ADRs written to `docs/adr/` matching the decisions in technical.md.
- `devlog/` placed at repo root so it covers both macOS and backend work.
- `.gitkeep` files added to all empty leaf directories for git tracking.

## Files touched
```
AGENTS.md
infrastructure/compose.yaml
protocol/README.md
docs/adr/0001–0007-*.md
devlog/README.md
devlog/000-project-scaffold.md
ConnectMe/App/               ← .gitkeep
ConnectMe/Domain/            ← .gitkeep (Models, UseCases)
ConnectMe/Features/          ← .gitkeep (7 sub-features)
ConnectMe/Platform/          ← .gitkeep (3 sub-modules)
ConnectMe/Networking/        ← .gitkeep
ConnectMe/Rendering/         ← .gitkeep
ConnectMe/Privacy/           ← .gitkeep
services/realtime-api/       ← directory tree
protocol/                    ← schemas + fixtures
infrastructure/              ← deployment + monitoring
docs/adr|privacy|testing|releases
scripts/
```

## Next
Week 1: Create signed macOS app shell with stable bundle ID, implement transparent NSPanel overlay, join Spaces/full-screen environments, add menu-bar escape controls.
