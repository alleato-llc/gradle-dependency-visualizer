# Dependency Visualization

## What

Interactive graph rendering of Gradle dependency trees. Users see a visual tree where node size reflects transitive dependency count, colors group related dependencies, and red highlights conflicts.

## How

### User flow

1. User selects a Gradle project (browse or drag-and-drop)
2. App validates `gradlew` exists in the directory
3. User picks a Gradle configuration and clicks "Load Dependencies"
4. App runs `./gradlew dependencies --configuration <config> --console=plain`
5. Parser converts ASCII tree output into `DependencyTree` model
6. Layout calculator positions nodes using Reingold-Tilford algorithm
7. Graph renders in a scrollable, zoomable canvas

### Data flow

```
ProjectSelectionView
  → ProjectSelectionViewModel.loadDependencies()
    → GradleRunner.runDependencies() (async, runs ./gradlew)
    → GradleDependencyParser.parse() (ASCII → DependencyTree)
  → ContentView.onChange(of: dependencyTree)
    → DependencyGraphViewModel(tree:)
      → TreeLayoutCalculator.layout() → [NodePosition]
    → DependencyGraphView renders nodes + edges
```

## Architecture

### Design decisions

- **SwiftUI ZStack** over Canvas for hit testing and native tooltips (`.help()`)
- **Reingold-Tilford layout** for deterministic, readable tree positioning without overlap
- **Proportional node sizing** via `log2(subtreeSize)` — visually distinguishes leaf nodes from large subtrees without overwhelming the graph
- **11 color themes** — Pastel, Ocean, Earth, Monochrome, High Contrast, Warm Gradient, Cool Gradient, Sunset, Forest, Neon, Nordic — each with 10 node colors assigned by `abs(group.hashValue) % 10`
- **Red fill** (`#FF6B6B`) for nodes with version conflicts
- **Bezier curve edges** using cubic curves with midpoint control points for smooth connections
- **Flattened edge list** in ViewModel avoids recursive `@ViewBuilder` which SwiftUI can't type-check

### Performance optimizations

- **Auto-collapse for large trees** — `DepthLimitCalculator` computes the deepest level where cumulative node count stays under 500. Trees with >500 nodes auto-set `maxVisibleDepth` on init, with a dismissible info banner explaining the collapse.
- **Viewport culling** — `ViewportCullingCalculator` filters nodes to those intersecting the visible scroll region + 300pt margin. Scroll bounds are tracked via `NSView.boundsDidChangeNotification` on the NSScrollView's clip view (captured by `ScrollViewFinder`). Culling is bypassed when bounds are zero (initial load, PNG export).
- **Table view default for very large trees** — trees with >5000 total nodes auto-switch to table view in `ContentView`.
- **Node count warning** — orange toolbar banner when >2000 visible nodes, suggesting depth reduction or table view.
- **PNG export safety** — memory estimated as `width * height * 4 * scale^2`; scale capped to stay under 256MB. Too-large canvases log an error suggesting JSON export instead.
- **O(1) position lookups** — `positionMap` dictionary replaces linear `first(where:)` scans in ViewModel
- **O(n) layout** — `TreeLayoutCalculator` passes a `positionIndex` dictionary alongside the positions array
- **Pre-computed omitted IDs** — `omittedIds: Set<String>` built once during init
- **Collapse/expand** — double-click to collapse subtrees; BFS via `childrenMap` computes hidden descendants
- **Depth limiter** — toolbar slider restricts maximum visible depth

### Core models

- `DependencyNode` — recursive tree node with `subtreeSize` computed property
- `DependencyTree` — root container with nodes and conflicts
- `NodePosition` — layout output (nodeId, x, y, subtreeSize)

### Core types

- `DependencyGraphViewModel` — computes layout, builds node/position/children/depth maps, owns zoom/search/collapse/depth/viewport state
- `DependencyGraphView` — renders edges then nodes with viewport tracking, depth slider, collapse gestures, and theme picker
- `GraphNodeView` — themed rounded rectangle with artifact name, version, and collapse indicator (▶/▼)
- `GraphEdgeView` — Bezier curve between parent bottom and child top
- `TreeLayoutCalculator` — Reingold-Tilford positioning algorithm with O(n) dictionary lookups

### File organization

```
GradleDependencyVisualizer/
  ViewModels/DependencyGraphViewModel.swift
  Views/Graph/
    DependencyGraphView.swift
    GraphNodeView.swift
    GraphEdgeView.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Layout/
    TreeLayoutCalculator.swift
    DepthLimitCalculator.swift
    ViewportCullingCalculator.swift
```

## Testing

- `TreeLayoutCalculatorTests` — verifies single node, child depth positioning, deep tree handling
- `DepthLimitCalculatorTests` — large tree depth recommendation, under-threshold passthrough, empty input, threshold scaling
- `ViewportCullingCalculatorTests` — inclusion/exclusion, partial overlap, margin expansion, empty input, scale effects
- `DependencyGraphViewModelTests` — position computation, color consistency, node sizing, search filtering, auto-collapse for large trees, node count warning, viewport culling skip/filter behavior

## Table View Alternative

A table view is available as an alternative to the graph (see [Dependency Table](DEPENDENCY_TABLE.md)). Users switch between Graph and Table via a segmented picker in the toolbar.

## Limitations

- Layout computation (`TreeLayoutCalculator`) is still eager — all nodes are positioned upfront even when auto-collapsed. At very large scales (200K+ nodes), this causes a noticeable init delay.
- `DependencyNode.subtreeSize` is a recursive computed property, making it O(n) per call. It is called per-node during layout, giving O(n^2) worst case for deep trees.
- Zoom uses `MagnifyGesture` (trackpad) plus toolbar +/- buttons
