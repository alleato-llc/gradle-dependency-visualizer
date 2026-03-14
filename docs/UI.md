# UI Architecture

macOS SwiftUI app following MVVM with protocol-based dependency injection.

## App Lifecycle

```
GradleDependencyVisualizerApp (@main)
  └─ DependencyContainer (holds protocol-typed dependencies)
       ├─ gradleRunner: GradleRunner       → ProcessGradleRunner
       ├─ dependencyParser: GradleDependencyParser → TextGradleDependencyParser
       └─ fileExporter: FileExporter       → PanelFileExporter
```

The container is created once at app launch and passed to `ContentView`.

## Screen Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Toolbar: [Graph|Table] [View Conflicts] [Validate Scopes]  │
│          [Detect Duplicates]                                │
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│  Sidebar     │  Detail Area                                 │
│              │                                              │
│  Project     │  ┌──────────────────────────────────────┐    │
│  Selection   │  │ Graph View or Table View             │    │
│              │  │                                      │    │
│  - Path      │  │ (VSplitView in graph mode)           │    │
│  - Config    │  │                                      │    │
│  - Modules   │  ├──────────────────────────────────────┤    │
│  - Load btn  │  │ Conflict Panel (optional)            │    │
│  - Stats     │  ├──────────────────────────────────────┤    │
│              │  │ Scope Validation Panel (optional)    │    │
│              │  ├──────────────────────────────────────┤    │
│              │  │ Duplicate Detection Panel (optional) │    │
│              │  └──────────────────────────────────────┘    │
└──────────────┴──────────────────────────────────────────────┘
```

The detail area uses `NavigationSplitView`. When a diff is active, it replaces the entire detail area with `DependencyDiffView`.

## Component Areas

### Sidebar — Project Selection

**View:** `ProjectSelectionView` → **ViewModel:** `ProjectSelectionViewModel`

Handles all project setup: path selection (browse or drag-and-drop), configuration picker, module discovery, dependency loading, and file import. Shows project stats (node count, distinct deps, max depth, conflicts) after loading.

**Subview:** `DropTargetView` — drag-and-drop zone for folders and `build.gradle` files.

**Key flows:**
- Browse → `NSOpenPanel` → `setProjectPath()` → validates `gradlew` exists
- Drop → `handleDroppedURL()` → auto-detects project root from build file path
- Import → `NSOpenPanel` → `TreeImporter.importTree()` for JSON/text files
- Load → `loadDependencies()` → single-module or `loadModulesConcurrently()` (up to 8 parallel)

### Detail — Graph View

**View:** `DependencyGraphView` → **ViewModel:** `DependencyGraphViewModel`

The primary visualization. Renders the dependency tree as an interactive node graph.

**Toolbar controls:**
- Search with prev/next match navigation (500ms debounce)
- Depth slider — limits visible tree depth via `DepthLimitCalculator`
- Zoom controls (0.1x–3.0x) + pinch gesture (`MagnifyGesture`)
- Theme picker (11 themes: Pastel, Ocean, Earth, Monochrome, High Contrast, Warm Gradient, Cool Gradient, Sunset, Forest, Neon, Nordic)
- Hide Omitted toggle
- Expand All / Reset Layout buttons
- Export PNG / Export JSON buttons
- Compare button (opens baseline file picker for diff)

**Graph rendering:**
- `ScrollView` > `ZStack` with positioned `GraphEdgeView` and `GraphNodeView` elements
- Layout computed by `TreeLayoutCalculator` (Reingold-Tilford algorithm)
- Node sizes proportional to `log2(subtreeSize)`
- Colors: red for conflicts, theme root color for roots, hash-based group coloring for others

**Interactions:**
- Double-click node → collapse/expand subtree
- Drag node → manual repositioning (position override)
- Search highlights matching nodes

**Subviews:**
- `GraphNodeView` — rounded rectangle with artifact name, version, optional badges
- `GraphEdgeView` — curved Bezier path between parent and child positions

### Detail — Table View

**View:** `DependencyTableView` → **ViewModel:** `DependencyTableViewModel`

Alternative flat/hierarchical table view, default for trees >5000 nodes.

**Two modes:**
- **Flat** — deduplicated list of all dependencies with occurrence count, conflict flag, versions, and parent list. Each row is a `DisclosureGroup` showing "used by" and version details.
- **Tree** — hierarchical `List` with `children: \.optionalChildren` showing the full tree structure

**Toolbar:** Mode picker, search, conflicts-only filter, entry count, export JSON.

### Bottom Panels

All bottom panels appear in a `VSplitView` below the graph (graph mode only). Each has a header with title, count badge, and Export JSON button, followed by a sortable `Table`.

#### Conflict Panel

**View:** `ConflictTableView` → **ViewModel:** `ConflictTableViewModel`

Shows version conflicts from the dependency tree. Created eagerly when tree loads. Toggled by "View Conflicts" / "Hide Conflicts" toolbar button (visible only when conflicts exist).

**Columns:** Dependency, Requested, Resolved (red), Requested By

#### Scope Validation Panel

**View:** `ScopeValidationView` → **ViewModel:** `ScopeValidationViewModel`

Shows test libraries found in production configurations. Created eagerly when tree loads. Toggled by "Validate Scopes" / "Hide Validation" toolbar button (visible only when issues exist).

**Columns:** Dependency, Version, Detected As (orange), Recommendation

#### Duplicate Detection Panel

**View:** `DuplicateDetectionView` → **ViewModel:** `DuplicateDetectionViewModel`

Shows duplicate dependencies across or within modules. Created and detected lazily on first button press (reads build files from disk). Toggled by "Detect Duplicates" / "Hide Duplicates" toolbar button (always visible in graph mode).

**Columns:** Dependency, Type (blue/purple), Modules, Versions (red if mismatch), Recommendation

### Overlay — Dependency Diff

**View:** `DependencyDiffView` → **ViewModel:** `DependencyDiffViewModel`

Replaces the entire detail area. Compares a baseline tree (imported from JSON/text file) against the current tree.

**Controls:** Swap direction button, filter toggles (Added/Removed/Changed/Unchanged), search, export JSON, back to graph.

**Columns:** Status (color-coded +/-/~/=), Dependency, Before, After

## ViewModel Conventions

All ViewModels follow the same pattern:

- `@Observable @MainActor final class`
- Constructor receives domain data + `FileExporter` dependency
- Immutable or lazy-computed `results` / `conflicts` / `entries`
- `SortField` enum + `sortField` / `sortAscending` state
- `sortedResults` computed property combining sort + filter
- `toggleSort(field:)` — same field toggles direction, new field resets ascending
- `exportAsJSON()` — serializes sorted results, calls `fileExporter.saveData()`

## Performance Strategies

| Threshold | Behavior |
|-----------|----------|
| >500 nodes | Auto-collapse via `DepthLimitCalculator`, performance notice shown |
| >2000 nodes | Warning bar in graph view |
| >5000 nodes | Default to table view instead of graph |
| Scroll | Viewport culling via `ViewportCullingCalculator` (300pt margin) |
| Search | 500ms debounce before filtering |
| PNG export | 256MB memory cap |
| Multi-module load | Up to 8 concurrent Gradle executions |

## State Management

```
ContentView (@State)
  ├─ projectSelectionViewModel    — always exists
  ├─ graphViewModel?              — created on tree load
  ├─ conflictViewModel?           — created on tree load
  ├─ tableViewModel?              — created on tree load
  ├─ scopeValidationViewModel?    — created on tree load
  ├─ duplicateDetectionViewModel? — created on first "Detect Duplicates" press
  ├─ diffViewModel?               — created on Compare action
  ├─ showConflicts                — panel visibility toggle
  ├─ showScopeValidation          — panel visibility toggle
  ├─ showDuplicates               — panel visibility toggle
  └─ detailMode                   — .graph or .table
```

All ViewModels are reset to `nil` when the tree is cleared. Panel visibility flags reset to `false` on new tree load.

## File Organization

```
GradleDependencyVisualizer/
├── App/
│   ├── GradleDependencyVisualizerApp.swift   — @main entry point
│   ├── ContentView.swift                     — root layout, state orchestration
│   ├── DependencyContainer.swift             — DI container
│   └── PanelFileExporter.swift               — NSSavePanel file export
├── ViewModels/
│   ├── ProjectSelectionViewModel.swift
│   ├── DependencyGraphViewModel.swift
│   ├── ConflictTableViewModel.swift
│   ├── DependencyTableViewModel.swift
│   ├── DependencyDiffViewModel.swift
│   ├── ScopeValidationViewModel.swift
│   └── DuplicateDetectionViewModel.swift
├── Views/
│   ├── ProjectSelection/
│   │   ├── ProjectSelectionView.swift
│   │   └── DropTargetView.swift
│   ├── Graph/
│   │   ├── DependencyGraphView.swift
│   │   ├── GraphNodeView.swift
│   │   └── GraphEdgeView.swift
│   ├── Table/
│   │   └── DependencyTableView.swift
│   ├── Conflict/
│   │   └── ConflictTableView.swift
│   ├── Diff/
│   │   └── DependencyDiffView.swift
│   ├── Validation/
│   │   └── ScopeValidationView.swift
│   └── Duplicate/
│       └── DuplicateDetectionView.swift
└── Error.swift                               — error enum + ErrorPresenter
```
