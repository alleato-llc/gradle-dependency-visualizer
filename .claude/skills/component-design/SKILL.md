---
name: component-design
description: Design guidelines for Swift macOS components — Views, ViewModels, Runners, Parsers, and Calculators. Covers responsibility boundaries, method sizing, composition, and when to decompose. Use when creating or reviewing Views, ViewModels, or service types.
version: 1.0.0
---

# Component Design

## Shared rules

These apply to all component types.

### Single responsibility first, then size

A type should be responsible for **one thing**. File size is a secondary signal — only evaluate it after confirming the type is properly decomposed.

If a file exceeds **300–500 lines**, evaluate whether it's doing too much. Ask:

1. Does this type have more than one reason to change?
2. Can the methods be grouped into clusters that serve different purposes?
3. Would extracting a cluster into its own type make both types clearer?

If the answer to all three is no — the type is genuinely one cohesive responsibility that happens to be large — that's fine. The constraint is a trigger to evaluate, not a hard limit.

### Method size

Most methods should naturally land at **20–30 lines** when they're doing one thing well.

**Up to 100 lines** is acceptable for orchestration methods in ViewModels that coordinate a sequence of steps — each step is a clear block, and extracting them into private methods would just scatter the narrative.

**Over 100 lines** is the trigger to evaluate.

### Method composition

Structure methods at **one level of abstraction**. A method should either coordinate high-level steps or implement low-level details — not both.

### Composition over inheritance

Prefer composing types with collaborators over building class hierarchies for code reuse.

```swift
// Good — each ViewModel owns its own ErrorPresenter
@Observable @MainActor
final class ProjectSelectionViewModel {
    let errorPresenter = ErrorPresenter()
    // ...
}
```

## Component types

| Component | Responsibility | Dependencies | Error handling |
|---|---|---|---|
| **View** | Display state, forward user actions | ViewModel via `@Bindable` | No `try`/`catch` — bind to ViewModel |
| **ViewModel** | Orchestrate workflows, validate input | Runners, Parsers via protocols | Catch errors, delegate to `ErrorPresenter` |
| **Runner** | External process boundary (protocol) | None (protocol) / Foundation.Process (impl) | Throws domain errors |
| **Parser** | Parse text output (protocol) | None (protocol) | Returns parsed result |
| **Calculator** | Pure computation | None | Returns plain values |

## View

Thin — bind to ViewModel, no business logic, no data fetching.

```swift
struct ProjectSelectionView: View {
    @Bindable var viewModel: ProjectSelectionViewModel

    var body: some View {
        // Bind to ViewModel state, forward user actions
    }
}
```

- No `try`/`catch` in views. No direct runner or parser calls.

## ViewModel

`@Observable @MainActor` classes. Orchestrate business logic, own an `ErrorPresenter`.

```swift
@Observable @MainActor
final class ProjectSelectionViewModel {
    private let gradleRunner: any GradleRunner
    private let dependencyParser: any GradleDependencyParser
    let errorPresenter = ErrorPresenter()

    init(gradleRunner: any GradleRunner, dependencyParser: any GradleDependencyParser) {
        self.gradleRunner = gradleRunner
        self.dependencyParser = dependencyParser
    }
}
```

- One ViewModel per screen. Constructor injection for dependencies.
- Catch errors and delegate to `ErrorPresenter`.

## Runner

Protocol defines the contract. Process implementation is the production version. One runner per external tool.

```swift
public protocol GradleRunner: Sendable {
    func runDependencies(projectPath: String, configuration: GradleConfiguration) async throws -> String
}
```

## Parser

Protocol defines the parsing contract. Text implementation parses Gradle ASCII tree output.

```swift
public protocol GradleDependencyParser: Sendable {
    func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree
}
```

## Calculator

Stateless enums with static methods for pure computation.

```swift
enum DependencyAnalysisCalculator {
    static func allNodes(from tree: DependencyTree) -> [DependencyNode] { ... }
    static func subtreeSizes(from tree: DependencyTree) -> [String: Int] { ... }
}
```

- No state, no dependencies, no side effects.
- Use `enum` to prevent instantiation. Unit-testable without setup.

## Conventions

- Views are thin — bind to ViewModel state, forward user actions
- ViewModels own `ErrorPresenter` — no error handling in Views
- One ViewModel per screen
- Calculators are stateless enums — pure computation, no side effects
- Constructor injection for all dependencies — no global state
- `@MainActor` only for ViewModels — services and models are non-isolated

## Checklist

When creating or reviewing components, verify:

- [ ] Views contain no business logic — only state binding and user action forwarding
- [ ] ViewModels orchestrate workflows and own error presentation
- [ ] Runners wrap external processes — domain types in, domain types out
- [ ] Parsers are stateless and return domain types
- [ ] Calculators are stateless with no side effects
- [ ] Methods stay at one level of abstraction
- [ ] Files under 300–500 lines; decompose if cohesion warrants it
