---
name: view-architecture
description: Thin SwiftUI views with ViewModel binding and macOS navigation patterns
version: 1.0.0
---

# View Architecture

Views are thin presentation layers that bind to ViewModels. No business logic in views.

## Principles

1. **Views bind to ViewModels** — `@Bindable var viewModel` for two-way binding to `@Observable` ViewModels
2. **No business logic in views** — views call ViewModel methods; all logic lives in the ViewModel
3. **macOS patterns** — `NavigationSplitView`, `NSOpenPanel`, `onDrop(of:)` for platform-native UX
4. **Break complex views into computed properties or private subviews**

## View structure

```swift
import SwiftUI
import GradleDependencyVisualizerCore

struct ProjectSelectionView: View {
    @Bindable var viewModel: ProjectSelectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DropTargetView(onDrop: { url in viewModel.handleDroppedURL(url) })
            Button("Load Dependencies") { viewModel.loadDependencies() }
        }
        .alert("Error", isPresented: $viewModel.isShowingError) {
            Button("OK") { viewModel.isShowingError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

## macOS-specific patterns

### Directory selection with NSOpenPanel

```swift
func selectProjectViaOpenPanel() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
        setProjectPath(url.path)
    }
}
```

### Drag-and-drop with onDrop

```swift
.onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: URL.self) { url, _ in
        if let url {
            Task { @MainActor in _ = onDrop(url) }
        }
    }
    return true
}
```

### NavigationSplitView layout

```swift
NavigationSplitView {
    ProjectSelectionView(viewModel: projectSelectionViewModel)
} detail: {
    if let graphViewModel {
        DependencyGraphView(viewModel: graphViewModel)
    } else {
        ContentUnavailableView("No Project Selected", ...)
    }
}
```

### Zoom with MagnifyGesture

```swift
.gesture(
    MagnifyGesture()
        .onChanged { value in
            viewModel.zoomScale = max(0.1, min(3.0, value.magnification))
        }
)
```

## Conventions

- View files live in `GradleDependencyVisualizer/Views/` grouped by feature (e.g., `Graph/`, `Conflict/`, `ProjectSelection/`)
- One primary view per file; private subviews in the same file are fine
- `@Bindable` for ViewModel binding, `@State` for view-local presentation state only
- Views never import `GradleDependencyVisualizerServices` directly unless needed for types (e.g., `NodePosition`)
- Toolbar buttons use SF Symbols via `Image(systemName:)`
- Use `.help()` modifier for tooltips on graph nodes
