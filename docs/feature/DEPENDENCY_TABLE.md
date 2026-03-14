# Dependency Table

## What

Table-based view of Gradle dependency trees as an alternative to the graph. Supports two modes: a **flat unique list** (one row per distinct `group:artifact` with expandable "used by" parents) and a **tree outline** (collapsible hierarchy matching the dependency tree structure).

## How

### User flow

1. After loading dependencies, a segmented Graph/Table picker appears in the toolbar
2. Switching to Table shows a flat list of unique dependencies by default
3. Each row shows coordinate, version, occurrence count, and a conflict badge if applicable
4. Expanding a row reveals parent dependencies ("used by") and version details
5. Switching to Tree mode shows the full dependency hierarchy as a collapsible outline
6. Search filters dependencies by coordinate; "Conflicts Only" toggle narrows to conflicting entries
7. "Export JSON" saves the current filtered/sorted view

### Data flow

```
ContentView.onChange(of: dependencyTree)
  → DependencyTableViewModel(tree:)
    → DependencyTableCalculator.flatEntries(from:)
      → DependencyAnalysisCalculator.allNodes(from:) (flatten tree)
      → DependencyTableCalculator.parentMap(from:) (walk tree tracking parents)
      → Group by coordinate, aggregate versions/counts/conflicts
    → [FlatDependencyEntry] stored in ViewModel
  → DependencyTableView renders flat list or tree outline
```

## Architecture

### Design decisions

- **Flat mode with DisclosureGroup** — each unique coordinate is a single row; expanding reveals "used by" parents and version details. This deduplicates the tree for scanning.
- **Tree mode with OutlineGroup** — uses `DependencyNode.optionalChildren` extension to drive SwiftUI's native collapsible list. Preserves the original tree hierarchy.
- **Stateless calculator** — `DependencyTableCalculator` is a stateless enum following the `DependencyAnalysisCalculator` pattern. Reuses `allNodes(from:)` for tree flattening.
- **Pre-computed flat entries** — `flatEntries` are computed once in ViewModel init, not on every render. Filtering/sorting operates on this cached list.
- **Segmented picker in toolbar** — Graph/Table toggle only appears when a tree is loaded and diff view is not active.

### Core models

- `FlatDependencyEntry` — `coordinate`, `version` (effective), `hasConflict`, `isOmitted`, `occurrenceCount`, `usedBy` (parent coordinates), `versions` (all observed versions)
- `DependencyNode.optionalChildren` — returns `nil` when `children` is empty (required by `OutlineGroup`)

### Core types

- `DependencyTableCalculator` — stateless enum with `flatEntries(from:)` and `parentMap(from:)`
- `DependencyTableViewModel` — owns flat entries, table mode, search, sort, conflict filter, JSON export
- `DependencyTableView` — flat mode (List + DisclosureGroup) and tree mode (List with children)

### File organization

```
GradleDependencyVisualizer/
  ViewModels/DependencyTableViewModel.swift
  Views/Table/DependencyTableView.swift
  Extensions/DependencyNode+OutlineGroup.swift
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/FlatDependencyEntry.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Analysis/DependencyTableCalculator.swift
```

## Testing

- `DependencyTableCalculatorTests` — flat entries from simple/conflict/empty trees, usedBy parents, version aggregation, parent map, sort order
- `DependencyTableViewModelTests` — init populates entries, default mode, sort toggling, search filtering, conflict-only filter, JSON export

## Limitations

- Tree mode does not filter/prune by search text — it shows the full tree (search only applies in flat mode)
- Flat mode "used by" shows parent coordinates, not the full dependency chain
- No column-header click sorting in the view — sorting is controlled via ViewModel `toggleSort(field:)`
