---
name: adding-unit-tests
description: Swift Testing for pure logic and ViewModel tests
version: 1.0.0
---

# Adding Unit Tests

Unit tests verify pure business logic and ViewModel behavior without external processes.

## When to use unit tests

| Component | Test type | Why |
|-----------|-----------|-----|
| Calculator (stateless enum) | Unit test | Pure logic, no dependencies |
| ViewModel | Unit test | Uses test doubles for runners/parsers |
| Parser | Unit test | Pure text parsing, no side effects |
| View | Manual / preview | No automated view tests |

## Framework

Use Swift Testing exclusively. No XCTest.

- `@Suite` on the test struct
- `@Test` on each test function
- `#expect` for assertions
- `#require` for unwrapping / preconditions that should fail the test

## Calculator tests (stateless enum)

Calculators are stateless enums with static methods. Tests call the static method directly.

```swift
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
import Testing

import GradleDependencyVisualizerServices

@Suite
struct DependencyAnalysisCalculatorTests {
    @Test
    func collectsAllNodes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let nodes = DependencyAnalysisCalculator.allNodes(from: tree)
        #expect(nodes.count == 3)
    }

    @Test
    func computesSubtreeSizes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let sizes = DependencyAnalysisCalculator.subtreeSizes(from: tree)
        #expect(sizes["org.springframework:spring-core"] == 3)
    }
}
```

## Parser tests

Parsers are tested with sample Gradle output strings.

```swift
@Suite
struct TextGradleDependencyParserTests {
    let parser = TextGradleDependencyParser()

    @Test
    func parsesConflictMarker() {
        let output = "+--- com.fasterxml.jackson.core:jackson-databind:2.13.0 -> 2.14.2"
        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots[0].hasConflict)
        #expect(tree.conflicts.count == 1)
    }
}
```

## ViewModel tests with test doubles

ViewModels require `@MainActor` on the test function. Inject test doubles from `GradleDependencyVisualizerTestSupport`.

```swift
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
import Testing

@testable import GradleDependencyVisualizer

@Suite
struct ProjectSelectionViewModelTests {
    @Test @MainActor
    func initialStateIsEmpty() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        #expect(viewModel.projectPath.isEmpty)
        #expect(viewModel.dependencyTree == nil)
    }
}
```

## Conventions

- Named `*Tests` (e.g., `TextGradleDependencyParserTests`)
- `@Suite` struct, not class
- One `@Test` per behavior, descriptive function name
- Use `TestDependencyTreeFactory` for test data — never construct models inline
- Use `#require` when an unwrap failure means the rest of the test is meaningless
- Cover: normal cases, edge cases, error conditions
- Assert on observable state (ViewModel properties, return values), not internal implementation
