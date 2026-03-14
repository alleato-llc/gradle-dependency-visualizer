# Dependency Diff

## What

Compare the current dependency tree against a baseline file (JSON or Gradle text output) to detect added, removed, and version-changed dependencies.

## How

### User flow

1. User loads a dependency tree in the graph view
2. Clicks "Compare..." in the toolbar
3. Selects a baseline file via `NSOpenPanel` (JSON or plain text)
4. `TreeImporter` auto-detects the file format and imports the baseline tree
5. `DependencyDiffCalculator` compares baseline vs current
6. Diff view replaces the graph with a filterable, sortable results table
7. User can dismiss to return to the graph

### Data flow

```
DependencyGraphView "Compare…" button
  → ContentView.compareAgainstBaseline()
    → NSOpenPanel → file URL
    → TreeImporter.importTree(from:fileName:fallbackConfiguration:)
    → DependencyDiffViewModel(baseline:current:fileExporter:)
      → DependencyDiffCalculator.diff(baseline:current:) → DependencyDiffResult
  → DependencyDiffView renders results
```

## Architecture

### Core types

- `DependencyDiffResult` — contains baseline/current names and an array of `DependencyDiffEntry`
- `DependencyDiffEntry` — coordinate, changeKind, before/after versions (requested and resolved)
- `DependencyDiffEntry.ChangeKind` — `.added`, `.removed`, `.versionChanged`, `.unchanged`
- `DependencyDiffCalculator` — stateless enum that computes the diff between two `DependencyTree`s
- `DependencyDiffViewModel` — manages filtering, search, sorting, direction swap, and JSON export

### Design decisions

- **Coordinate-level comparison** — dependencies are compared by `group:artifact`, not by tree position. Duplicate coordinates are collapsed, preferring non-omitted/non-constraint nodes.
- **Resolved version priority** — uses `resolvedVersion` when available, falling back to `requestedVersion` for comparisons
- **Direction swap** — users can swap baseline/current to reverse the comparison without reimporting
- **Default filter** — unchanged dependencies are hidden by default to focus on differences
- **Color-coded status** — green for added, red for removed, orange for version changed

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/DependencyDiffResult.swift
  Sources/.../Models/DependencyDiffEntry.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Analysis/DependencyDiffCalculator.swift
GradleDependencyVisualizer/
  ViewModels/DependencyDiffViewModel.swift
  Views/Diff/DependencyDiffView.swift
```

## Testing

- `DependencyDiffCalculatorTests` — identical trees, added/removed detection, version changes, resolved version preference, empty baseline/current, duplicate collapsing, sorted output
- `DependencyDiffViewModelTests` — filter toggles, search filtering, default hides unchanged, export, sort toggling, direction swap
