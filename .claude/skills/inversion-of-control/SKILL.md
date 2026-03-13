---
name: inversion-of-control
description: Protocols as contracts with constructor injection via DependencyContainer
version: 1.0.0
---

# Inversion of Control

## Protocol Location

Protocols live in `GradleDependencyVisualizerServices`. Production impls alongside them. Test fakes in `GradleDependencyVisualizerTestSupport`.

```swift
// In GradleDependencyVisualizerServices
public protocol GradleRunner: Sendable {
    func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String
}

public protocol GradleDependencyParser: Sendable {
    func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree
}
```

## Test Fakes

Controllable behavior via stored properties for assertions.

```swift
// In GradleDependencyVisualizerTestSupport
public final class TestGradleRunner: GradleRunner, @unchecked Sendable {
    public var outputToReturn: String = ""
    public var errorToThrow: Error?
    public var runDependenciesCallCount = 0

    public func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String {
        runDependenciesCallCount += 1
        if let error = errorToThrow { throw error }
        return outputToReturn
    }
}
```

## DependencyContainer

A struct in the app target wires production implementations.

```swift
@MainActor
struct DependencyContainer {
    let gradleRunner: any GradleRunner
    let dependencyParser: any GradleDependencyParser

    init() {
        self.gradleRunner = ProcessGradleRunner()
        self.dependencyParser = TextGradleDependencyParser()
    }
}
```

## Constructor Injection

ViewModels accept `any ProtocolName` via initializer. Wire from container at the app entry point.

```swift
@Observable @MainActor
final class ProjectSelectionViewModel {
    private let gradleRunner: any GradleRunner
    private let dependencyParser: any GradleDependencyParser

    init(gradleRunner: any GradleRunner, dependencyParser: any GradleDependencyParser) {
        self.gradleRunner = gradleRunner
        self.dependencyParser = dependencyParser
    }
}
```

## Rules

- Use `any ProtocolName` (existential type) for dependency declarations.
- Constructor injection only — no `@Environment` for domain dependencies.
- `DependencyContainer` is the single wiring point.
- Test fakes expose stored properties (`outputToReturn`, `errorToThrow`) for assertion and control.
- Production code never imports `GradleDependencyVisualizerTestSupport`.
