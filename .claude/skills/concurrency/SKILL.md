---
name: concurrency
description: Swift concurrency with async/await and MainActor isolation
version: 1.0.0
---

# Concurrency

Swift structured concurrency with `@MainActor` isolation for UI-bound code. No GCD.

## Actor isolation rules

| Component | Isolation | Why |
|-----------|-----------|-----|
| ViewModels | `@MainActor` | Publish state to SwiftUI views |
| GradleRunner protocol | Non-isolated | External process calls are async |
| GradleDependencyParser protocol | Non-isolated | Pure parsing, no UI dependency |
| Services / Calculators | Non-isolated | Pure logic, no actor requirement |
| Models | Non-isolated | Value types or `Sendable` classes |

## ViewModel pattern

ViewModels are `@Observable @MainActor`. Use `Task {}` for async work.

```swift
@Observable
@MainActor
final class ProjectSelectionViewModel {
    private(set) var isLoading = false
    var dependencyTree: DependencyTree?

    private let gradleRunner: any GradleRunner

    func loadDependencies() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let output = try await gradleRunner.runDependencies(
                    projectPath: projectPath,
                    configuration: selectedConfiguration
                )
                dependencyTree = dependencyParser.parse(output: output, ...)
            } catch {
                errorPresenter.present(error)
            }
        }
    }
}
```

## Protocol isolation

Runner protocols are non-isolated with async methods because they execute external processes.

```swift
public protocol GradleRunner: Sendable {
    func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String
}
```

Parser protocols are non-isolated and synchronous because they're pure computation.

```swift
public protocol GradleDependencyParser: Sendable {
    func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree
}
```

## Sendable conformance

- `DependencyNode` is `final class` + `Sendable` (immutable reference type for recursive tree)
- `DependencyConflict`, `DependencyTree` are `Sendable` structs
- Test doubles for async protocols use `@unchecked Sendable` when they have mutable state
- `ProcessGradleRunner` uses `withCheckedThrowingContinuation` to bridge Foundation.Process to async/await

## Conventions

- No `DispatchQueue` — use Swift concurrency exclusively
- `@MainActor` test functions when testing ViewModels
- `async throws` for external process calls
- Use `any Protocol` for existential protocol types in stored properties
- `withCheckedThrowingContinuation` for bridging callback-based APIs
