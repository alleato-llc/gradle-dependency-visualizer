---
name: project-structure
description: Modular packages with domain-oriented organization and 7-file directory limit
version: 1.0.0
---

# Project Structure

## Package Layout

Three Swift packages plus the app target and CLI tool. Dependency flows one direction: App/CLI -> Services -> Core.

```
GradleDependencyVisualizer/
  App/
    GradleDependencyVisualizerApp.swift
    DependencyContainer.swift
    ContentView.swift
  ViewModels/
  Views/
    Graph/
    Conflict/
    ProjectSelection/
  Error.swift
GradleDependencyVisualizerCLI/
  GradleDependencyVisualizerCLI.swift
Packages/
  GradleDependencyVisualizerCore/         # Pure models, no dependencies
  GradleDependencyVisualizerServices/     # Business logic, protocols, implementations
  GradleDependencyVisualizerTestSupport/  # Fakes, factories, test helpers
```

## Package Responsibilities

### GradleDependencyVisualizerCore

Pure value types and model definitions. No business logic, no external dependencies.

```swift
.target(name: "GradleDependencyVisualizerCore")
```

Contains: `DependencyNode`, `DependencyConflict`, `DependencyTree`, `GradleConfiguration`.

### GradleDependencyVisualizerServices

Protocols, business logic, and production implementations. Depends only on Core.

```swift
.target(
    name: "GradleDependencyVisualizerServices",
    dependencies: ["GradleDependencyVisualizerCore"]
)
```

Contains: parser protocols, runner protocols, calculators, layout algorithms, export logic.

### GradleDependencyVisualizerTestSupport

Test fakes, factories, and helpers. Depends on both Core and Services.

```swift
.target(
    name: "GradleDependencyVisualizerTestSupport",
    dependencies: ["GradleDependencyVisualizerCore", "GradleDependencyVisualizerServices"]
)
```

Contains: `TestGradleRunner`, `TestGradleDependencyParser`, `TestDependencyTreeFactory`.

## App Target Structure

```
App/                  # App entry point, dependency wiring
ViewModels/           # @Observable view models
Views/
  Graph/              # Dependency graph visualization
  Conflict/           # Conflict table
  ProjectSelection/   # Folder selection + drag-and-drop
```

## CLI Target

```
GradleDependencyVisualizerCLI/
  GradleDependencyVisualizerCLI.swift   # ArgumentParser with graph + conflicts subcommands
```

Shares Core + Services packages with the GUI app. Uses `swift-argument-parser` as its only external dependency.

## Rules

- **7-file directory limit**: When a directory exceeds 7 files, evaluate whether to split into subdirectories by feature or subdomain.
- **Domain-oriented naming**: Directories named after domain concepts (`Graph/`, `Conflict/`), not technology (`Network/`, `Database/`).
- **One public type per file**: File name matches the primary type it contains.
- **No circular dependencies**: Package dependency graph is strictly `App/CLI -> Services -> Core`. TestSupport sits alongside, never imported by production code.
- **Feature directories under Views/**: Each feature gets its own subdirectory.

## Adding a New Feature

1. Models in `GradleDependencyVisualizerCore`. 2. Protocols + impls in `GradleDependencyVisualizerServices`. 3. Test fakes in `GradleDependencyVisualizerTestSupport`. 4. ViewModel in `ViewModels/`. 5. Views in `Views/{FeatureName}/`. 6. Wire in `DependencyContainer`.

## Anti-Patterns

- Business logic in the app target instead of Services package.
- Importing `GradleDependencyVisualizerTestSupport` in production code.
- `Utilities/` or `Helpers/` grab-bag directories.
