# Gradle Dependency Visualizer

macOS SwiftUI app + CLI that visualizes Gradle dependency trees with conflict detection.

## Build Commands

```bash
# Generate Xcode project
xcodegen generate

# Build macOS app
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' build

# Build CLI tool
xcodebuild -scheme GradleDependencyVisualizerCLI -destination 'platform=macOS' build

# Run package tests (Services layer)
cd Packages/GradleDependencyVisualizerServices && swift test

# Run app tests (ViewModels)
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' test
```

## Architecture

- **Pattern**: MVVM with protocol-based dependency injection
- **Platform**: macOS 14+, Swift 6.0
- **Reactivity**: `@Observable` (Observation framework)
- **Concurrency**: `async`/`await`, `@MainActor` for ViewModels
- **Testing**: Swift Testing framework (`@Suite`, `@Test`, `#expect`)

## Module Structure

- **GradleDependencyVisualizerCore** — Domain models (`DependencyNode`, `DependencyTree`, `DependencyConflict`, `GradleConfiguration`, `FlatDependencyEntry`)
- **GradleDependencyVisualizerServices** — Business logic (parsing, execution, layout, export, analysis)
- **GradleDependencyVisualizerTestSupport** — Test doubles and factories
- **GradleDependencyVisualizer** — macOS SwiftUI app (Views, ViewModels, DI container)
- **GradleDependencyVisualizerCLI** — CLI tool (`graph` and `conflicts` subcommands)

## Component Naming

- ViewModels: `*ViewModel` (`@Observable @MainActor final class`)
- Calculators: `*Calculator` (stateless enums with static methods — analysis/computation)
- Generators: `*Generator` (stateless enums — produce formatted text/data output)
- Exporters: `*Exporter` (stateless enums — serialize domain types to a format)
- Importers: `*Importer` (stateless enums — deserialize from a format to domain types)
- Protocols: `GradleRunner`, `GradleDependencyParser`
- Test doubles: `Test*` prefix, `@unchecked Sendable`
- Factories: `Test*Factory` with sensible defaults

## Documentation

Detailed documentation in `docs/`:

- [Architecture](docs/ARCHITECTURE.md) — System design, component responsibilities, domain models
- [Data Models](docs/DATA_MODELS.md) — All domain models, properties, conformances, ID patterns
- [UI Architecture](docs/UI.md) — Screen layout, component areas, ViewModel conventions, state management
- [Testing](docs/TESTING.md) — Testing strategy, infrastructure, conventions
- [Dependency Visualization](docs/feature/DEPENDENCY_VISUALIZATION.md) — Graph rendering feature
- [Conflict Detection](docs/feature/CONFLICT_DETECTION.md) — Conflict detection feature
- [Dependency Table](docs/feature/DEPENDENCY_TABLE.md) — Table view feature (flat + tree modes)
- [Multi-Module Support](docs/feature/MULTI_MODULE_SUPPORT.md) — Multi-module project discovery and loading
- [Dependency Diff](docs/feature/DEPENDENCY_DIFF.md) — Baseline comparison and change detection
- [Scope Validation](docs/feature/SCOPE_VALIDATION.md) — Test library scope checking
- [Duplicate Detection](docs/feature/DUPLICATE_DETECTION.md) — Cross-module and within-module duplicate dependency detection
- [Import / Export](docs/feature/IMPORT_EXPORT.md) — File import and multi-format export
- [Project Selection](docs/feature/PROJECT_SELECTION.md) — Project setup, configuration, and loading

## Key Design Decisions

- App Sandbox **disabled** — must execute `./gradlew` as child process
- No persistence — in-memory only
- Gradle ASCII tree parser is stack-based (no native JSON output from Gradle)
- Graph rendering uses SwiftUI ZStack with positioned views (not Canvas) for hit testing/tooltips
- Reingold-Tilford tree layout for deterministic, readable graphs
- Node sizes proportional to `log2(subtreeSize)`
- 11 color themes (Pastel, Ocean, Earth, Monochrome, High Contrast, Warm Gradient, Cool Gradient, Sunset, Forest, Neon, Nordic) assigned by group name hash; red for conflict nodes
- O(1) position lookups via `positionMap` dictionary; O(n) layout via `positionIndex` in `TreeLayoutCalculator`
- Auto-collapse via `DepthLimitCalculator` for trees >500 nodes; viewport culling via `ViewportCullingCalculator` using `NSView.boundsDidChangeNotification` on the scroll view clip view (300pt margin); table view default for >5000 nodes; PNG export memory cap at 256MB
- Collapse/expand subtrees via double-click; depth limiter slider

## Skills

Available skills in `.claude/skills/`:

### Production
- **project-structure** — Modular packages, directory layout, core/services split
- **component-design** — Views, ViewModels, Runners, Parsers, Calculators
- **naming-conventions** — `*ViewModel`, `*Runner`, `*Parser`, `*Calculator`, `*View`
- **inversion-of-control** — Protocols as contracts, constructor injection, DependencyContainer
- **error-handling** — Error enum with associated values, ErrorPresenter
- **view-architecture** — Thin SwiftUI views, macOS patterns (NSOpenPanel, drag-and-drop, MagnifyGesture)
- **concurrency** — `async`/`await`, `@MainActor`, `Task`, `Sendable`
- **state-management** — `@Observable`, `@State`, `@Bindable`

### Project
- **project-documentation** — Required documentation structure

### Testing
- **adding-unit-tests** — Swift Testing for pure logic, parsers, and ViewModels
- **test-data-isolation** — Fresh data per test, factory helpers with defaults
- **testing-boundaries** — Protocol-conforming fakes, call capture, configurable errors
- **adding-integration-tests** — ViewModel tests with test doubles
