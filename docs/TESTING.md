# Testing

## Testing Strategy

| Component | Test Type | Location | Why |
|-----------|-----------|----------|-----|
| Calculator | Unit test | `Packages/.../Tests/` | Pure logic, no dependencies |
| Parser | Unit test | `Packages/.../Tests/` | Stateless text parsing |
| Layout | Unit test | `Packages/.../Tests/` | Deterministic algorithm |
| Export | Unit test | `Packages/.../Tests/` | Deterministic output generation |
| ViewModel | Integration test | `GradleDependencyVisualizerTests/` | Uses test doubles for runners/parsers |
| View | Manual / preview | — | No automated view tests |

## Running Tests

```bash
# Package-level tests (parsers, calculators, layout, export)
cd Packages/GradleDependencyVisualizerServices && swift test

# App-level tests (ViewModels)
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' test

# All tests
cd Packages/GradleDependencyVisualizerServices && swift test && cd ../.. && \
xcodebuild -scheme GradleDependencyVisualizer -destination 'platform=macOS' test
```

## Test Framework

Swift Testing exclusively. No XCTest.

- `@Suite` on test structs
- `@Test` on each test function
- `#expect` for assertions
- `#require` for unwrapping / preconditions
- `@MainActor` on ViewModel test functions

## Test Infrastructure

### Test Doubles

Protocol-conforming fakes in `GradleDependencyVisualizerTestSupport`:

| Fake | Protocol | Key Properties |
|------|----------|----------------|
| `TestGradleRunner` | `GradleRunner` | `outputToReturn`, `errorToThrow`, `runDependenciesCallCount` |
| `TestGradleDependencyParser` | `GradleDependencyParser` | `treeToReturn`, `parseCallCount` |

Fakes use `@unchecked Sendable` when they have mutable state conforming to `Sendable` protocols.

### Test Factory

`TestDependencyTreeFactory` provides factory methods with sensible defaults:

| Method | Returns | Purpose |
|--------|---------|---------|
| `makeSimpleTree()` | Tree with 3 nodes | Basic tree structure |
| `makeTreeWithConflicts()` | Tree with 1 conflict | Conflict detection testing |
| `makeDeepTree(depth:)` | Chain of N nodes | Deep nesting testing |
| `makeNode(...)` | Single node | Custom node construction |

## Test Suites

### Package Tests (151 tests)

| Suite | Tests | What it covers |
|-------|-------|----------------|
| `TextGradleDependencyParserTests` | 10 | Simple deps, nesting, conflicts, markers, edge cases |
| `TreeLayoutCalculatorTests` | 3 | Single node, children positioning, deep trees |
| `DepthLimitCalculatorTests` | 4 | Large tree depth recommendation, under-threshold passthrough, empty input, threshold scaling |
| `ViewportCullingCalculatorTests` | 6 | Inclusion/exclusion, partial overlap, margin expansion, empty input, scale effects |
| `DotExportGeneratorTests` | 3 | DOT structure, labels, conflict highlighting |
| `ConflictReportGeneratorTests` | 4 | Text/JSON reports, empty/populated conflicts |
| `DependencyAnalysisCalculatorTests` | 4 | Node collection, coordinates, subtree sizes, grouping |
| `DependencyTableCalculatorTests` | 7 | Flat entries, conflicts, usedBy, parent map, version aggregation, sorting |
| Plus additional suites | — | JSON/text round-trips, importers, exporters, diff, scope validation, multi-module, integration |

### App Tests (54 tests)

| Suite | Tests | What it covers |
|-------|-------|----------------|
| `ProjectSelectionViewModelTests` | 7 | Initial state, invalid path error, validation, module discovery, multi-module |
| `DependencyGraphViewModelTests` | 23 | Position map, O(1) lookups, color consistency, node sizing, search, collapse/expand, depth limiting, auto-collapse for large trees, performance notice, node count warning, viewport culling skip/filter, pre-computed omitted IDs, JSON export |
| `ConflictTableViewModelTests` | 5 | Conflict loading, sorting, toggle behavior |
| `DependencyTableViewModelTests` | 7 | Flat entries init, table mode, sort toggling, search filtering, conflict filtering, JSON export |
| `DependencyDiffViewModelTests` | 6 | Diff computation, sorting, export |
| `ScopeValidationViewModelTests` | 6 | Results loading, sorting, toggle, export |

## Conventions

- Named `*Tests` (e.g., `TextGradleDependencyParserTests`)
- `@Suite` struct, not class
- One `@Test` per behavior, descriptive function name
- Use `TestDependencyTreeFactory` for test data — never construct models inline
- Each test creates its own data — no shared mutable state
- Test both success and error paths
- Assert on observable state (ViewModel properties, return values), not internal implementation
- Derive expected values from inputs, not hardcoded magic values
