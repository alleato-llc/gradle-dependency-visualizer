---
name: project-documentation
description: Defines the required documentation structure for the project. Covers root-level files (README, CLAUDE.md) and docs/ directory. Use when creating a new project or adding features.
version: 1.0.0
---

# Project Documentation

Every project must include a standard set of documentation.

## Required structure

```
README.md                    High-level overview, quickstart
CLAUDE.md                    Agent context, references docs/

docs/
├── ARCHITECTURE.md          System architecture, component design, package layout
├── TESTING.md               Testing strategy, test types, conventions
└── feature/
    └── FEATURE_N.md         Per-feature deep dives
```

## Root-level files

### README.md
- Project name and one-sentence description
- Prerequisites
- Quickstart (build, run, test)
- High-level architecture overview
- Project structure (directory tree)
- Link to `docs/` for detailed documentation

### CLAUDE.md
- Agent context for Claude Code
- Project overview, build commands, architecture summary
- References to `docs/` for detailed documentation
- Lists available skills

## docs/ files

### ARCHITECTURE.md
- System overview
- Component responsibilities and interactions (Views, ViewModels, Runners, Parsers, Calculators)
- Domain model overview (DependencyNode, DependencyTree, DependencyConflict)
- Key design decisions (ASCII parser, graph layout algorithm, no persistence)
- Package structure (Core, Services, TestSupport)
- macOS-specific adaptations (NSOpenPanel, drag-and-drop, no sandbox)

### TESTING.md
- Testing strategy (unit vs integration, when to use which)
- How to run tests (`swift test`, `xcodebuild test`)
- Test infrastructure (test doubles, factory pattern)
- Test conventions (naming, location, assertions)

### Feature docs (docs/feature/FEATURE_N.md)

Each feature gets its own document with sections: What, How, Architecture, Testing, Limitations.

## When to create/update docs

| Event | Action |
|---|---|
| New project | Create all root files and docs/ structure |
| New feature | Add `docs/feature/FEATURE_NAME.md` |
| Architecture change | Update `ARCHITECTURE.md` |
| New test pattern | Update `TESTING.md` |

## Conventions

- Docs describe what exists — never document aspirational features
- Keep docs close to code — update docs in the same PR as the code change
- CLAUDE.md is the entry point — it should reference docs/ for details, not duplicate them
- Do not create documentation unless explicitly requested or required by a feature change
- Documentation files use uppercase names with `.md` extension
