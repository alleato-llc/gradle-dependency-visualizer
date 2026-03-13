---
name: error-handling
description: Error enum with associated values and centralized ErrorPresenter
version: 1.0.0
---

# Error Handling

## Error Enum

A single error type with associated values covers all failure cases.

```swift
enum GradleDependencyVisualizerError: Error, LocalizedError {
    case invalidProjectPath
    case gradlewNotFound
    case parsingFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectPath:
            "The selected path is not a valid directory."
        case .gradlewNotFound:
            "No Gradle wrapper (gradlew) found in the selected directory."
        case .parsingFailed(let message):
            "Failed to parse Gradle output: \(message)"
        case .executionFailed(let message):
            "Gradle execution failed: \(message)"
        }
    }
}
```

- One enum for the entire app. Associated `String` values carry context.
- Conforms to `LocalizedError` for user-facing messages.
- Service-specific errors (e.g., `GradleRunnerError`) live in their respective service files.

## ErrorPresenter

`@Observable @MainActor` class managing error display state. One per ViewModel.

```swift
@Observable @MainActor
final class ErrorPresenter {
    var currentError: GradleDependencyVisualizerError?
    var isShowingError = false

    var errorMessage: String {
        currentError?.localizedDescription ?? "An unknown error occurred."
    }

    func present(_ error: Error) {
        if let gradleError = error as? GradleDependencyVisualizerError {
            currentError = gradleError
        } else {
            currentError = .executionFailed(error.localizedDescription)
        }
        isShowingError = true
    }

    func dismiss() {
        currentError = nil
        isShowingError = false
    }
}
```

## ViewModel Pattern

Catch errors in async methods, delegate to `ErrorPresenter`.

```swift
func loadDependencies() {
    Task {
        do {
            let output = try await gradleRunner.runDependencies(...)
            dependencyTree = dependencyParser.parse(output: output, ...)
        } catch {
            errorPresenter.present(error)
        }
    }
}
```

- Every `async throws` call wrapped in `do`/`catch`.
- No `try?` that silently swallows errors. Document if intentionally ignored.

## View Alert Binding

```swift
.alert("Error", isPresented: $viewModel.isShowingError) {
    Button("OK") { viewModel.isShowingError = false }
} message: {
    Text(viewModel.errorMessage)
}
```

- One `.alert` per view, bound to ViewModel's error state.
- No error handling logic in the view.

## Testing Errors

```swift
@Test @MainActor
func loadDependenciesWithInvalidPathShowsError() {
    let runner = TestGradleRunner()
    let parser = TestGradleDependencyParser()
    let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

    viewModel.loadDependencies()

    #expect(viewModel.isShowingError)
}
```
