---
name: state-management
description: Observable ViewModels with State and Bindable property wrappers
version: 1.0.0
---

# State Management

`@Observable` ViewModels own application state. SwiftUI property wrappers connect views to state.

## Property wrapper guide

| Wrapper | Use | Where |
|---------|-----|-------|
| `@Observable` | Mark a class as observable | ViewModel class declaration |
| `@Bindable` | Two-way binding to `@Observable` object | View property for its ViewModel |
| `@State` | View-local state (presentation, toggles) | View struct |

## ViewModel as `@Observable`

ViewModels use `@Observable` (not `ObservableObject`). Properties update views automatically.

```swift
@Observable
@MainActor
final class ProjectSelectionViewModel {
    // Read-write — views can bind for two-way interaction
    var projectPath: String = ""
    var selectedConfiguration: GradleConfiguration = .compileClasspath
    var isLoading = false
    var dependencyTree: DependencyTree?

    // ErrorPresenter owns error state
    let errorPresenter = ErrorPresenter()

    // Computed properties — derived state, automatically updates
    var hasValidProject: Bool {
        !projectPath.isEmpty && FileManager.default.fileExists(atPath: projectPath)
    }
}
```

## View binding with `@Bindable`

`@Bindable` creates two-way bindings (`$viewModel.property`) to `@Observable` objects.

```swift
struct ProjectSelectionView: View {
    @Bindable var viewModel: ProjectSelectionViewModel

    var body: some View {
        TextField("Project path", text: $viewModel.projectPath)
        Picker("Configuration", selection: $viewModel.selectedConfiguration) {
            ForEach(GradleConfiguration.allCases, id: \.self) { config in
                Text(config.displayName).tag(config)
            }
        }
    }
}
```

## View-local state with `@State`

Use `@State` for presentation concerns that do not belong in the ViewModel.

```swift
struct ContentView: View {
    @State private var showConflicts = false

    var body: some View {
        // ...
        .toolbar {
            Button(showConflicts ? "Hide Conflicts" : "View Conflicts") {
                showConflicts.toggle()
            }
        }
    }
}
```

## onChange for cross-ViewModel coordination

```swift
.onChange(of: projectSelectionViewModel.dependencyTree) { _, tree in
    if let tree {
        graphViewModel = DependencyGraphViewModel(tree: tree)
        conflictViewModel = ConflictTableViewModel(tree: tree)
    }
}
```

## Conventions

- `@Observable` replaces `ObservableObject` / `@Published` — do not use the older pattern
- Computed properties for derived state — no redundant stored state
- `@State` is only for view-local presentation concerns (sheet visibility, toggles)
- `@Bindable` is required for `$` binding syntax with `@Observable` objects
- Dependencies flow via initializer injection, not `@Environment`
