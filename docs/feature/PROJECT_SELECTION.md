# Project Selection

## What

Sidebar UI for selecting a Gradle project, choosing a configuration, discovering modules, and loading the dependency tree.

## How

### User flow

1. User provides a Gradle project path via:
   - Drag-and-drop a folder or `build.gradle(.kts)` file onto the sidebar
   - Click "Browse..." to open `NSOpenPanel`
   - Type a path directly in the text field
2. App validates that `gradlew` (or `gradlew.bat`) exists in the directory
3. User selects a Gradle configuration from 11 options with descriptions
4. Optionally clicks "Discover Modules" for multi-module projects
5. Clicks "Load Dependencies" to run Gradle and parse the output
6. Sidebar shows tree statistics: total nodes, distinct dependencies, max depth, conflict count

### Supported configurations

| Configuration | Description |
|--------------|-------------|
| `compileClasspath` | Dependencies needed to compile main source code (most common) |
| `runtimeClasspath` | Dependencies available at runtime |
| `implementationDependenciesMetadata` | Internal metadata for `implementation` deps |
| `compileOnly` | Compile-time only, not packaged |
| `runtimeOnly` | Runtime only, not available at compile time |
| `api` | Exposed to consumers (java-library plugin) |
| `annotationProcessor` | Annotation processors |
| `testCompileClasspath` | Test compilation dependencies |
| `testRuntimeClasspath` | Test runtime dependencies |
| `testImplementation` | Test-only dependencies |
| `testAnnotationProcessor` | Test annotation processors |

### Data flow

```
ProjectSelectionView
  → Drag-and-drop / Browse / Text field → projectPath
  → Configuration picker → selectedConfiguration
  → "Discover Modules" → ProjectSelectionViewModel.listProjects()
    → GradleRunner.runProjects() → GradleProjectListParser.parse()
  → "Load Dependencies" → ProjectSelectionViewModel.loadDependencies()
    → GradleRunner.runDependencies() → GradleDependencyParser.parse()
  → dependencyTree published → ContentView.onChange creates ViewModels
```

## Architecture

### Core types

- `ProjectSelectionViewModel` — orchestrates path validation, module discovery, dependency loading, file import, and error presentation
- `ProjectSelectionView` — sidebar UI with drop target, path input, config picker, module list, load button
- `DropTargetView` — reusable drop zone for folders and build files
- `ErrorPresenter` — centralized error display

### Design decisions

- **Path validation** — checks for `gradlew` existence before enabling "Load Dependencies"
- **Configuration guide** — expandable `DisclosureGroup` with descriptions for each Gradle configuration
- **Auto-discovery** — if modules haven't been discovered, `loadDependencies()` automatically discovers them first
- **Drag-and-drop** — accepts both directories and `build.gradle(.kts)` files; extracts parent directory from file drops
- **File import** — supports importing previously exported JSON or saved Gradle text output, bypassing Gradle execution entirely

### File organization

```
GradleDependencyVisualizer/
  ViewModels/ProjectSelectionViewModel.swift
  Views/ProjectSelection/
    ProjectSelectionView.swift
    DropTargetView.swift
  App/ContentView.swift (tree change handler)
```

## Testing

- `ProjectSelectionViewModelTests` — initial empty state, invalid path error, module discovery, single-module bypass, auto-discovery on load, concurrent multi-module loading, `hasValidProject` validation
