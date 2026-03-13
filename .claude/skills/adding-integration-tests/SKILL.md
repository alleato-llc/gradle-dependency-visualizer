---
name: adding-integration-tests
description: Integration tests that exercise ViewModels with test doubles. Covers assertion patterns and derive-from-inputs. Use when testing component interactions.
version: 1.0.0
---

# Adding Integration Tests

Integration tests exercise a component with its dependencies — test doubles for ViewModels.

## ViewModel tests (with test doubles)

Test the ViewModel layer using fakes from `GradleDependencyVisualizerTestSupport`. Inject the fake, exercise the ViewModel method, assert on ViewModel state and fake call counts.

```swift
@Suite
struct ProjectSelectionViewModelTests {
    @Test @MainActor
    func loadDependenciesWithInvalidPathShowsError() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        viewModel.loadDependencies()

        #expect(viewModel.isShowingError)
    }
}
```

## What to assert on

Assert on **observable side effects**, not internal implementation:

1. **ViewModel state** — published properties after the operation (`dependencyTree`, `isShowingError`)
2. **Test double call counts** — verify delegation happened (`runner.runDependenciesCallCount == 1`)
3. **Error state** — `isShowingError`, `errorMessage` after error injection
4. **Negative assertions** — verify side effects did NOT happen on failure paths

### Derive expected values from inputs

Do not hardcode expected values when they can be computed from the test inputs:

```swift
// Good — derived from the input, documents the contract
let tree = TestDependencyTreeFactory.makeSimpleTree()
let viewModel = DependencyGraphViewModel(tree: tree)
#expect(viewModel.nodeMap.count == tree.totalNodeCount)
```

## Conventions

- ViewModel tests: `@Suite` struct, `@Test @MainActor` per test function
- Use `TestDependencyTreeFactory` for test data — override only what matters
- Use `#expect` for assertions, `#require` for preconditions that must hold
- Test both success and error paths
- Named `*Tests` (e.g., `ProjectSelectionViewModelTests`, `DependencyGraphViewModelTests`)
- ViewModel tests live in `GradleDependencyVisualizerTests/` (app target)
- Service/calculator tests live in `Packages/GradleDependencyVisualizerServices/Tests/`

## Checklist

When writing or reviewing integration tests, verify:

- [ ] ViewModel tests inject test doubles, not real runners/parsers
- [ ] Each test creates its own data — no shared mutable state
- [ ] Both success and error paths tested
- [ ] Assertions use observable state (ViewModel properties, return values, call counts)
- [ ] Error injection tested via `errorToThrow`
- [ ] Expected values derived from inputs, not hardcoded
