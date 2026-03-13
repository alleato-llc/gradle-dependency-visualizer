# Architecture

## System Overview

Gradle Visualizer is a macOS SwiftUI app (+ CLI) that runs Gradle's `dependencies` task, parses the ASCII tree output, and renders an interactive dependency graph with conflict detection.

The system follows MVVM with protocol-based dependency injection. All business logic lives in SPM packages; the app target is a thin UI shell.

```
┌─────────────────────┐     ┌──────────────────────┐
│  GradleDependencyVisualizer   │     │  GradleDependencyVisualizerCLI │
│  (macOS SwiftUI)    │     │  (ArgumentParser)    │
└────────┬────────────┘     └────────┬─────────────┘
         │                           │
         ▼                           ▼
┌─────────────────────────────────────────────────┐
│            GradleDependencyVisualizerServices             │
│  Parsing │ Execution │ Layout │ Export │ Analysis│
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│            GradleDependencyVisualizerCore                 │
│  DependencyNode │ DependencyTree │ Conflict     │
└─────────────────────────────────────────────────┘
```

## Package Structure

### GradleDependencyVisualizerCore

Pure domain models with no dependencies.

| Type | Kind | Purpose |
|------|------|---------|
| `DependencyNode` | `final class` (Sendable) | Tree node with group, artifact, version, children |
| `DependencyConflict` | `struct` | Records a version conflict (requested vs resolved) |
| `DependencyTree` | `struct` | Root container with nodes, conflicts, metadata |
| `GradleConfiguration` | `enum` | Gradle configurations (compileClasspath, runtimeClasspath, etc.) |

`DependencyNode` is a reference type because the dependency tree is recursive. It is immutable and `Sendable`.

### GradleDependencyVisualizerServices

Business logic organized by concern:

| Directory | Types | Responsibility |
|-----------|-------|----------------|
| `Parsing/` | `GradleDependencyParser` (protocol), `TextGradleDependencyParser` | Parse Gradle ASCII tree output |
| `Execution/` | `GradleRunner` (protocol), `ProcessGradleRunner` | Execute `./gradlew` via Foundation.Process |
| `Layout/` | `TreeLayoutCalculator`, `NodePosition` | Reingold-Tilford tree layout algorithm |
| `Export/` | `DotExportCalculator`, `ConflictReportCalculator` | DOT format and conflict report generation |
| `Analysis/` | `DependencyAnalysisCalculator` | Node collection, subtree sizes, conflict grouping |

### GradleDependencyVisualizerTestSupport

Test infrastructure shared across test targets:

| Type | Purpose |
|------|---------|
| `TestDependencyTreeFactory` | Factory with sensible defaults for test trees |
| `TestGradleRunner` | Fake runner with configurable output and errors |
| `TestGradleDependencyParser` | Fake parser with configurable return tree |

## Component Responsibilities

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| **View** | Display state, forward user actions | ViewModel via `@Bindable` |
| **ViewModel** | Orchestrate workflows, validate input | Runners, Parsers via protocols |
| **Runner** | External process boundary | Foundation.Process |
| **Parser** | Text parsing | None |
| **Calculator** | Pure computation | None |

## Domain Model

```
DependencyTree
├── projectName: String
├── configuration: GradleConfiguration
├── roots: [DependencyNode]
└── conflicts: [DependencyConflict]

DependencyNode (recursive tree)
├── group, artifact, requestedVersion
├── resolvedVersion? (set when conflict exists)
├── isOmitted, isConstraint
├── children: [DependencyNode]
└── computed: hasConflict, subtreeSize, coordinate, displayVersion

DependencyConflict
├── coordinate (group:artifact)
├── requestedVersion, resolvedVersion
└── requestedBy (parent coordinate)
```

## Key Design Decisions

### Gradle ASCII Parsing

Gradle has no native JSON output for the `dependencies` task. The parser handles:
- Tree prefixes: `+---`, `\---`, `|    ` — depth = prefix length / 5
- Conflict markers: `requested:version -> resolved:version`
- Special markers: `(*)` omitted, `(c)` constraint, `(n)` unresolvable
- Stack-based algorithm to reconstruct tree from indentation depth

### Graph Visualization

- **Custom SwiftUI views** in a ScrollView + ZStack — not Canvas — for hit testing and tooltips
- **Reingold-Tilford layout** — deterministic, readable tree positioning
- **Proportional node sizing** — `baseSize + scaleFactor * log2(subtreeSize)`, min 60pt, max 200pt
- **11 color themes** (Pastel, Ocean, Earth, Monochrome, High Contrast, Warm Gradient, Cool Gradient, Sunset, Forest, Neon, Nordic) — 10 node colors each, assigned by group name hash
- **Red nodes** for dependencies with version conflicts
- **Zoom** via MagnifyGesture + toolbar buttons, **pan** via ScrollView

### Large Graph Performance

- **O(1) position lookups** — `positionMap` dictionary replaces linear `first(where:)` scans
- **Pre-computed omitted IDs** — `omittedIds: Set<String>` built once in init
- **O(n) layout** — `TreeLayoutCalculator` uses `positionIndex` dictionary instead of `positions.last(where:)` per child
- **Viewport culling** — only nodes within the visible scroll region (+ 200pt padding) are rendered
- **Collapse/expand subtrees** — double-click to collapse; BFS via `childrenMap` computes hidden descendants
- **Depth limiter** — toolbar slider restricts maximum visible tree depth

### macOS Adaptations

- `NSOpenPanel` for directory selection (not UIDocumentPicker)
- `onDrop(of: [UTType.fileURL])` for drag-and-drop
- App Sandbox **disabled** — must execute `./gradlew` as child process
- No persistence (SwiftData/CoreData) — in-memory only
- `WindowGroup` with `NavigationSplitView`

### CLI Design

- `swift-argument-parser` (only external dependency, CLI target only)
- `graph` subcommand: outputs DOT format for piping to Graphviz
- `conflicts` subcommand: text or JSON conflict reports
- Shares Core + Services packages with the GUI app
