---
name: naming-conventions
description: Naming rules for Swift macOS types — *ViewModel for orchestrators, *Runner for external process boundaries, *Calculator for standalone logic. Use when creating new types or reviewing naming.
version: 1.0.0
---

# Naming Conventions

## Type suffixes

| Suffix | When to use | Depends on other components? | Example |
|---|---|---|---|
| `*View` | SwiftUI view | Yes — ViewModel | `DependencyGraphView` |
| `*ViewModel` | Orchestrates business logic for a screen | Yes — runners, parsers | `ProjectSelectionViewModel` |
| `*Runner` | External process boundary (protocol or impl) | Yes — Foundation.Process (impl) | `GradleRunner` |
| `*Parser` | Text/data parsing boundary (protocol or impl) | No — takes text, returns domain types | `GradleDependencyParser` |
| `*Calculator` | Standalone logic — pure computation | No — takes inputs, returns outputs | `DependencyAnalysisCalculator` |
| `*Presenter` | Centralized UI concern (e.g., error display) | No — holds state for View binding | `ErrorPresenter` |
| `*Factory` | Test data builders | No — creates test objects | `TestDependencyTreeFactory` |

### Key rule: `*ViewModel` implies dependencies

A type named `*ViewModel` tells the reader it orchestrates other components — it has constructor-injected dependencies. If a type performs self-contained logic with no dependencies, use `*Calculator`.

## Protocol vs Implementation vs Test Fake

| Layer | Naming rule | Example |
|---|---|---|
| Protocol | Plain domain name | `GradleRunner`, `GradleDependencyParser` |
| Production impl | Technology/context prefix | `ProcessGradleRunner`, `TextGradleDependencyParser` |
| Test fake | `Test` prefix | `TestGradleRunner`, `TestGradleDependencyParser` |

```swift
// Protocol — plain domain name
protocol GradleRunner { ... }

// Production — context prefix describing technology
struct ProcessGradleRunner: GradleRunner { ... }

// Test fake — Test prefix
final class TestGradleRunner: GradleRunner { ... }
```

## Test type suffixes

| Suffix | Type | Example |
|---|---|---|
| `*Tests` | Test suite (Swift Testing `@Suite`) | `TextGradleDependencyParserTests` |
| `*CalculatorTests` | Pure logic tests | `DependencyAnalysisCalculatorTests` |

## Method naming

### Factory methods in test helpers

Use `make*` prefix for test data factory methods:

```swift
public static func makeSimpleTree(projectName: String = "test-project") -> DependencyTree { ... }
public static func makeNode(group: String = "com.example", ...) -> DependencyNode { ... }
```

### View action methods

Use imperative verbs for ViewModel methods triggered by user actions:

```swift
func loadDependencies() { ... }
func selectProjectViaOpenPanel() { ... }
func handleDroppedURL(_ url: URL) -> Bool { ... }
```

## File naming

Files match their primary type name:

```
GradleRunner.swift                   # Protocol
ProcessGradleRunner.swift            # Production implementation
TestGradleRunner.swift               # Test fake
DependencyGraphView.swift            # View
DependencyGraphViewModel.swift       # ViewModel
DependencyAnalysisCalculator.swift   # Calculator
```

## Model and Enum naming

Domain models use plain nouns — no suffix. Enums use descriptive names.

```swift
final class DependencyNode { ... }
struct DependencyConflict { ... }
struct DependencyTree { ... }
enum GradleConfiguration: String { ... }
```

## Conventions

- Protocols use plain domain names — never `I*` or `*Protocol` prefixes/suffixes
- Production implementations are prefixed by technology/context (`Process*`, `Text*`)
- Test fakes are prefixed with `Test`
- Files are named after their primary type
- `*ViewModel` implies constructor-injected dependencies — use `*Calculator` for standalone logic

## Checklist

When creating or reviewing types, verify:

- [ ] Type suffix matches its responsibility (ViewModel, Runner, Parser, Calculator, View)
- [ ] Protocols use plain domain names without prefixes or suffixes
- [ ] Implementations use technology prefix (Process*, Text*, Test*)
- [ ] File name matches the primary type name
- [ ] `*ViewModel` types actually have dependencies — standalone logic uses descriptive names
- [ ] Test factory methods use `make*` prefix
