---
name: test-data-isolation
description: Ensures tests are independent by using factory helpers with sensible defaults. Tests must not depend on data from other tests. Use when writing or reviewing tests.
version: 1.0.0
---

# Test Data Isolation

Each test must be fully independent — it creates its own data and never assumes or depends on state left by other tests.

## Principles

### 1. Every test creates its own data

Tests must not read, reference, or depend on data created by other tests. Each test arranges its own inputs and asserts only on the outputs it produces.

```swift
// Good — creates its own tree, then asserts on it
let tree = TestDependencyTreeFactory.makeSimpleTree()
let viewModel = DependencyGraphViewModel(tree: tree)
#expect(viewModel.nodeMap.count == tree.totalNodeCount)
```

### 2. Test doubles start empty

Test doubles (e.g., `TestGradleRunner`) begin with default behavior. Each test configures what it needs.

```swift
@Test @MainActor
func loadDependenciesCallsRunner() async {
    let runner = TestGradleRunner()
    runner.outputToReturn = sampleGradleOutput
    let parser = TestGradleDependencyParser()
    parser.treeToReturn = TestDependencyTreeFactory.makeSimpleTree()
    let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)
    // ...
}
```

### 3. Each test creates its own fresh instances

Never share a test double instance between test functions.

## Factory pattern

`TestDependencyTreeFactory` is a stateless enum in the `GradleDependencyVisualizerTestSupport` package. Every parameter has a default value so tests only specify what matters.

```swift
public enum TestDependencyTreeFactory {
    public static func makeSimpleTree(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .compileClasspath
    ) -> DependencyTree { ... }

    public static func makeNode(
        group: String = "com.example",
        artifact: String = "lib",
        requestedVersion: String = "1.0.0",
        ...
    ) -> DependencyNode { ... }
}
```

Override only the parameters the test cares about; rely on factory defaults for everything else.

## Checklist

When writing or reviewing tests, verify:

- [ ] Each test creates its own data
- [ ] No test reads or references data created by another test
- [ ] Assertions reference the test's own data — not hardcoded expected values
- [ ] Test doubles are fresh per test function
