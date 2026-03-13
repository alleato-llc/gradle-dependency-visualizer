---
name: testing-boundaries
description: Creates protocol-conforming fakes that honor the contract at each external boundary. Covers call capture, configurable errors, and Sendable isolation. Use when adding a new protocol boundary or testing ViewModel/service interactions.
version: 1.0.0
---

# Testing Boundaries

Every external dependency sits behind a contract boundary — a protocol that defines what the dependency does, not how it does it. This skill covers how to create test implementations that honor the contract, and how to verify your code uses the contract correctly.

## Shared principles

### 1. Fakes over mocks

Hand-written protocol-conforming fakes with configurable behavior. No mock libraries — the fake is a real class with real behavior.

### 2. Contract fidelity

A test implementation must behave like the real implementation at the contract level:
- **Return configured data** — `outputToReturn` returns the configured string
- **Respect error semantics** — throw when `errorToThrow` is set
- **Track calls** — increment call counts for verification

### 3. Call capture

Track every invocation so tests can assert on what was called:

```swift
public var runDependenciesCallCount = 0
public var lastProjectPath: String?
public var lastConfiguration: GradleConfiguration?
```

### 4. Configurable errors

All fakes support error injection via `errorToThrow`:

```swift
public var errorToThrow: Error?

public func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String {
    runDependenciesCallCount += 1
    if let error = errorToThrow { throw error }
    return outputToReturn
}
```

### 5. Reset between tests

Each test function creates its own fresh fake instance. No shared state between tests.

## Location

Fakes live in the `GradleDependencyVisualizerTestSupport` package:

```
Packages/GradleDependencyVisualizerTestSupport/Sources/GradleDependencyVisualizerTestSupport/
├── TestDependencyTreeFactory.swift     Factory with sensible defaults
├── TestGradleRunner.swift              Fake runner
└── TestGradleDependencyParser.swift    Fake parser
```

## Runner fake pattern

Runner protocols are non-isolated and async, so fakes use `@unchecked Sendable`.

```swift
public final class TestGradleRunner: GradleRunner, @unchecked Sendable {
    public var outputToReturn: String = ""
    public var errorToThrow: Error?
    public var runDependenciesCallCount = 0
    public var lastProjectPath: String?
    public var lastConfiguration: GradleConfiguration?

    public init() {}

    public func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String {
        runDependenciesCallCount += 1
        lastProjectPath = projectPath
        lastConfiguration = configuration
        if let error = errorToThrow { throw error }
        return outputToReturn
    }
}
```

## Parser fake pattern

Parser protocols are synchronous, so fakes are simpler.

```swift
public final class TestGradleDependencyParser: GradleDependencyParser, @unchecked Sendable {
    public var treeToReturn: DependencyTree?
    public var parseCallCount = 0

    public init() {}

    public func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree {
        parseCallCount += 1
        return treeToReturn ?? DependencyTree(projectName: projectName, configuration: configuration, roots: [], conflicts: [])
    }
}
```

## Conventions

- Fakes live in `Packages/GradleDependencyVisualizerTestSupport/Sources/GradleDependencyVisualizerTestSupport/`
- Named `Test*` (e.g., `TestGradleRunner`, `TestGradleDependencyParser`)
- All properties `public` so tests can configure and inspect them
- Tracked properties use `public` — tests both read and write
- Provide sensible default return values so tests only configure what they need
- `@unchecked Sendable` for fakes with mutable state conforming to `Sendable` protocols
- Each test creates its own fresh fake instance

## Checklist

When creating or reviewing test fakes, verify:

- [ ] Fake conforms to the full protocol — no missing methods
- [ ] Error injection via `errorToThrow` property
- [ ] Call counts tracked for every method
- [ ] Sensible defaults provided for return values
- [ ] `@unchecked Sendable` when protocol requires `Sendable`
- [ ] Each test creates its own fresh fake — no shared state
