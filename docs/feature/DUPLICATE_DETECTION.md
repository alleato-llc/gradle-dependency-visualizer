# Duplicate Dependency Detection

## What

Detects duplicate dependencies at two levels: the same `group:artifact` declared as a direct dependency across multiple modules (cross-module), and the same `group:artifact` declared multiple times within a single `build.gradle(.kts)` file (within-module). Flags version mismatches and recommends consolidation.

## How

### User flow

1. User loads a dependency tree (single or multi-module)
2. Clicks "Detect Duplicates" in the toolbar (only visible when duplicates are found)
3. Duplicate results panel appears below the graph in a `VSplitView`
4. Results show each duplicate with its type (cross-module or within-module), affected modules, versions, and recommendation
5. User can sort by any column and export as JSON

### Data flow

```
ContentView toolbar "Detect Duplicates" button
  → DuplicateDetectionViewModel(tree:fileExporter:projectPath:modules:)
    → DuplicateDependencyCalculator.detect(tree:projectPath:modules:)
      → detectCrossModule(tree:) → finds shared deps across synthetic module nodes
      → detectWithinModule(projectPath:modules:) → parses build.gradle files for repeated declarations
    → [DuplicateDependencyResult]
  → DuplicateDetectionView renders sortable table
```

## Architecture

### Core types

- `DuplicateDependencyResult` — coordinate, kind (cross-module/within-module), affected modules, version map, mismatch flag, recommendation
- `GradleBuildFileParser` — stateless enum that extracts dependency declarations from `build.gradle`/`build.gradle.kts` content via regex
- `DuplicateDependencyCalculator` — stateless enum with `detectCrossModule`, `detectWithinModule`, and combined `detect` methods
- `DuplicateDetectionViewModel` — manages sorting, direction toggle, and JSON export

### Design decisions

- **Two detection levels** — cross-module detection uses the existing dependency tree (synthetic module nodes from `MultiModuleTreeCalculator`); within-module detection reads build files from disk
- **Cross-module detection** — identifies synthetic module nodes via `requestedVersion == "module"`, collects direct children by coordinate, keeps those appearing in 2+ modules. Requires at least 2 modules.
- **Within-module detection** — derives build file path from `projectPath` + module Gradle path (`:app:feature` → `app/feature/build.gradle`). Tries `.kts` first, falls back to `.gradle`. For single-module projects, reads `projectPath/build.gradle(.kts)` directly.
- **Build file parser** — supports Groovy string (`implementation 'g:a:v'`), Kotlin DSL (`implementation("g:a:v")`), and Groovy map notation (`implementation group: 'g', name: 'a', version: 'v'`). Tracks line numbers. Skips line and block comments.
- **Version mismatch flagging** — cross-module results compare versions; mismatches get red text and "Version mismatch — standardize" recommendation; matching versions get "Consolidate to root project"
- **v1 limitations** — does not parse version catalogs (`libs.x`), variable interpolation (`$var`), `platform()`/BOM declarations, or dependencies from `buildSrc`/convention plugins

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/DuplicateDependencyResult.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Parsing/GradleBuildFileParser.swift
  Sources/.../Analysis/DuplicateDependencyCalculator.swift
GradleDependencyVisualizer/
  ViewModels/DuplicateDetectionViewModel.swift
  Views/Duplicate/DuplicateDetectionView.swift
```

## Testing

- `GradleBuildFileParserTests` — Groovy single/double quote, Kotlin DSL, Groovy map notation, multiple configurations, line number tracking, comment skipping, non-dependency lines, empty input
- `DuplicateDependencyCalculatorTests` — shared dep across modules, unique deps (no results), version mismatch detection, single-module exclusion, within-module duplicate declaration, within-module no duplicates, sorted output
- `DuplicateDetectionViewModelTests` — init loads results, default sort field, sort toggling, single-module empty results, export
