# Multi-Module Project Support

## What

Automatic discovery and concurrent loading of Gradle multi-module (multi-project) builds. Users see a unified dependency tree with synthetic module nodes as top-level roots.

## How

### User flow

1. User selects a Gradle project directory
2. App runs `./gradlew projects --console=plain` to discover submodules
3. `GradleProjectListParser` extracts module names and paths (e.g., `:app`, `:lib:core`)
4. Module picker appears with checkboxes and select all / deselect all
5. User clicks "Load Dependencies"
6. App loads selected modules concurrently (up to 8 in parallel via `TaskGroup`)
7. `MultiModuleTreeCalculator` assembles a combined tree with synthetic module roots
8. Graph and table views render the unified tree

### Data flow

```
ProjectSelectionView
  → ProjectSelectionViewModel.listProjects()
    → GradleRunner.runProjects() → GradleProjectListParser.parse() → [GradleModule]
  → ProjectSelectionViewModel.loadDependencies()
    → TaskGroup (max 8 concurrent)
      → GradleRunner.runDependencies(module:) per module
      → GradleDependencyParser.parse() per module
    → MultiModuleTreeCalculator.assemble() → DependencyTree
```

### Single-module fallback

When `./gradlew projects` returns no submodules, the app skips module discovery and loads dependencies directly — no synthetic module nodes are created.

## Architecture

### Core types

- `GradleModule` — model with `name` and `path` (e.g., name=`core`, path=`:lib:core`)
- `GradleProjectListParser` — parses `gradle projects` output with regex to extract module paths
- `MultiModuleTreeCalculator` — assembles module trees into a unified `DependencyTree` with synthetic root nodes (group=projectName, artifact=moduleName, version="module")
- `ProjectSelectionViewModel` — orchestrates discovery, concurrent loading, and error handling

### Design decisions

- **Concurrent loading** via `TaskGroup` with `maxConcurrency: 8` — balances speed with Gradle process limits
- **Synthetic module nodes** — each module becomes a top-level root node whose children are that module's dependency roots
- **Conflict aggregation** — conflicts from all modules are merged into the combined tree
- **Auto-discovery** — if the user hasn't explicitly discovered modules, `loadDependencies()` auto-runs discovery first

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/GradleModule.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Parsing/GradleProjectListParser.swift
  Sources/.../Analysis/MultiModuleTreeCalculator.swift
GradleDependencyVisualizer/
  ViewModels/ProjectSelectionViewModel.swift
  Views/ProjectSelection/ProjectSelectionView.swift
```

## Testing

- `GradleProjectListParserTests` — standard output parsing, nested submodules, empty/no-submodule cases
- `MultiModuleTreeCalculatorTests` — two-module assembly, conflict aggregation, single module, empty modules, synthetic node coordinates
- `ProjectSelectionViewModelTests` — module discovery, single-module bypass, auto-discovery on load, concurrent multi-module loading
