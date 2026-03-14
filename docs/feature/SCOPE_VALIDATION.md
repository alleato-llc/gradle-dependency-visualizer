# Scope Validation

## What

Detects test framework libraries that appear in production Gradle configurations (e.g., `compileClasspath`, `runtimeClasspath`) and recommends moving them to test-scoped configurations.

## How

### User flow

1. User loads a dependency tree
2. Clicks "Validate Scopes" in the toolbar (only visible when issues are found)
3. Validation results panel appears below the graph in a `VSplitView`
4. Results show each misplaced dependency with its detected library name and recommended scope
5. User can sort by any column and export as JSON

### Data flow

```
ContentView toolbar "Validate Scopes" button
  → ScopeValidationViewModel(tree:fileExporter:)
    → DependencyScopeValidator.validate(tree:) → [ScopeValidationResult]
  → ScopeValidationView renders sortable table
```

## Architecture

### Core types

- `ScopeValidationResult` — coordinate, version, matched library name, current configuration, recommended scope
- `DependencyScopeValidator` — stateless enum that scans a tree for test libraries in production configs
- `ScopeValidationViewModel` — manages sorting, direction toggle, and JSON export

### Design decisions

- **Production-only validation** — only scans production configurations (`compileClasspath`, `runtimeClasspath`, `implementation`, `runtimeOnly`, `compileOnly`, `api`). Test configurations (e.g., `testCompileClasspath`) are skipped.
- **70+ test libraries** — recognizes JUnit 4/5, Mockito, TestNG, Spring Test, AssertJ, Hamcrest, PowerMock, Arquillian, REST Assured, WireMock, Cucumber, Spock, and more
- **Matching strategies** — exact coordinate match (e.g., `junit:junit`) and wildcard group match (e.g., `org.junit.jupiter.*`)
- **Deduplication** — same coordinate appearing multiple times is reported once
- **Scope recommendations** — suggests `testImplementation` for compile-time test deps, `testRuntimeOnly` for runtime-only test deps

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/ScopeValidationResult.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Analysis/DependencyScopeValidator.swift
GradleDependencyVisualizer/
  ViewModels/ScopeValidationViewModel.swift
  Views/Validation/ScopeValidationView.swift
```

## Testing

- `DependencyScopeValidatorTests` — production config detection, test config exclusion, no-test-libraries case, wildcard/exact/sub-group matching, deduplication, sorted output, all production configs checked
- `ScopeValidationViewModelTests` — init loads results, default sort field, sort toggling, test config empty results, export
