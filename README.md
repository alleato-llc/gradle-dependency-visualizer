# Gradle Dependency Visualizer

A macOS SwiftUI app and CLI tool that visualizes Gradle dependency trees with interactive graph rendering and conflict detection.

![Graph](./docs/screenshots/graph.png)

## Prerequisites

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Quickstart

```bash
# Generate Xcode project
xcodegen generate

# Build and run the app
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' build
open GradleDependencyVisualizer.xcodeproj

# Build the CLI tool
xcodebuild -scheme GradleDependencyVisualizerCLI -destination 'platform=macOS' build

# Run tests
cd Packages/GradleDependencyVisualizerServices && swift test   # Package tests (24 tests)
cd ../..
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' test   # App tests (25 tests)
```

## How It Works

1. Drop a Gradle project folder (or browse with NSOpenPanel)
2. The app runs `./gradlew dependencies --configuration <config> --console=plain`
3. Parses the ASCII tree output into a structured dependency tree
4. Renders an interactive graph with proportional node sizing, conflict highlighting, 11 color themes, subtree collapse/expand, depth limiting, and viewport culling for large graphs

## Architecture

MVVM with protocol-based dependency injection across three Swift packages:

```
Packages/
├── GradleDependencyVisualizerCore/           Domain models (DependencyNode, DependencyTree, etc.)
├── GradleDependencyVisualizerServices/       Business logic (parsing, execution, layout, export)
└── GradleDependencyVisualizerTestSupport/    Test doubles and factories

GradleDependencyVisualizer/                   macOS SwiftUI app
├── App/                            Entry point, DependencyContainer, ContentView
├── ViewModels/                     @Observable view models
└── Views/                          SwiftUI views (Graph/, Conflict/, ProjectSelection/)

GradleDependencyVisualizerCLI/                CLI tool (graph + conflicts subcommands)
```

Dependency flow: `App/CLI → Services → Core`. TestSupport is test-only.

## CLI Usage

```bash
# Output DOT format graph
./gradle-dependency-visualizer graph /path/to/project --configuration compileClasspath | dot -Tpng -o deps.png

# Report conflicts as text
./gradle-dependency-visualizer conflicts /path/to/project

# Report conflicts as JSON
./gradle-dependency-visualizer conflicts /path/to/project --format json
```

## Documentation

See `docs/` for detailed documentation:

- [Architecture](docs/ARCHITECTURE.md) — System design, component responsibilities, domain models
- [Testing](docs/TESTING.md) — Testing strategy, infrastructure, conventions
- [Dependency Visualization](docs/feature/DEPENDENCY_VISUALIZATION.md) — Graph rendering feature
- [Conflict Detection](docs/feature/CONFLICT_DETECTION.md) — Conflict detection feature
