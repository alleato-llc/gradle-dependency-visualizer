import SwiftUI
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

/// Finds the enclosing NSScrollView from any NSView in the hierarchy.
private struct ScrollViewFinder: NSViewRepresentable {
    var onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: view) {
                onFound(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func findScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let parent = current?.superview {
            if let scrollView = parent as? NSScrollView {
                return scrollView
            }
            current = parent
        }
        return nil
    }
}

struct DependencyGraphView: View {
    @Bindable var viewModel: DependencyGraphViewModel
    var onCompare: (() -> Void)?
    @State private var baseScale: CGFloat = 1.0
    @State private var depthSliderValue: Double = 0
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var nsScrollView: NSScrollView?
    @State private var boundsObserver: NSObjectProtocol?
    @State private var showPerformanceNotice: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if let notice = viewModel.performanceNotice, showPerformanceNotice {
                HStack {
                    Image(systemName: "info.circle")
                    Text(notice)
                    Spacer()
                    Button("Dismiss") {
                        showPerformanceNotice = false
                    }
                    .buttonStyle(.borderless)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.bar)
            }

            if let warning = viewModel.nodeCountWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(warning)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.bar)
            }

            ScrollView([.horizontal, .vertical]) {
                graphContent(scaled: true)
                    .background(
                        ScrollViewFinder { scrollView in
                            setupScrollViewObserver(scrollView)
                        }
                    )
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        viewModel.zoomScale = max(0.1, min(3.0, baseScale * value.magnification))
                    }
                    .onEnded { _ in
                        baseScale = viewModel.zoomScale
                    }
            )
        }
        .onAppear {
            depthSliderValue = Double(viewModel.maxVisibleDepth ?? viewModel.maxTreeDepth)
        }
        .onDisappear {
            if let observer = boundsObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.focusedMatchIndex = 0
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                scrollToFocusedMatch()
            }
        }
    }

    private func scrollToFocusedMatch() {
        guard let nodeId = viewModel.focusedMatchId,
              let scrollView = nsScrollView else { return }

        let center = viewModel.effectivePosition(for: nodeId)
        let scale = viewModel.zoomScale

        // Target point in scaled content coordinates
        let targetX = center.x * scale
        let targetY = center.y * scale

        // Scroll so the node is centered in the visible area
        let clipBounds = scrollView.contentView.bounds
        let contentSize = scrollView.documentView?.frame.size ?? .zero

        let scrollX = max(0, min(targetX - clipBounds.width / 2, contentSize.width - clipBounds.width))
        // NSScrollView has flipped coordinates (origin at top-left for flipped documentView)
        let scrollY: CGFloat
        if scrollView.documentView?.isFlipped == true {
            scrollY = max(0, min(targetY - clipBounds.height / 2, contentSize.height - clipBounds.height))
        } else {
            // Non-flipped: origin at bottom-left, SwiftUI content grows downward
            let flippedTargetY = contentSize.height - targetY
            scrollY = max(0, min(flippedTargetY - clipBounds.height / 2, contentSize.height - clipBounds.height))
        }

        let newOrigin = NSPoint(x: scrollX, y: scrollY)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.contentView.animator().setBoundsOrigin(newOrigin)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private var toolbar: some View {
        HStack {
            TextField("Search dependencies…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onSubmit {
                    viewModel.focusNextMatch()
                    scrollToFocusedMatch()
                }

            if !viewModel.sortedMatchIds.isEmpty {
                HStack(spacing: 4) {
                    Text("\(viewModel.focusedMatchIndex % viewModel.sortedMatchIds.count + 1)/\(viewModel.sortedMatchIds.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button(action: {
                        viewModel.focusPreviousMatch()
                        scrollToFocusedMatch()
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Button(action: {
                        viewModel.focusNextMatch()
                        scrollToFocusedMatch()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Spacer()

            if viewModel.maxTreeDepth > 0 {
                HStack(spacing: 4) {
                    Text("Depth: \(viewModel.maxVisibleDepth.map(String.init) ?? "All") / \(viewModel.maxTreeDepth)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 80)

                    Slider(
                        value: $depthSliderValue,
                        in: 1...Double(viewModel.maxTreeDepth),
                        step: 1
                    )
                    .frame(width: 100)
                    .onChange(of: depthSliderValue) { _, newValue in
                        let intValue = Int(newValue)
                        viewModel.maxVisibleDepth = intValue >= viewModel.maxTreeDepth ? nil : intValue
                    }

                    Button("Show All") {
                        viewModel.maxVisibleDepth = nil
                        depthSliderValue = Double(viewModel.maxTreeDepth)
                    }
                    .font(.caption)
                    .fixedSize()
                }
            }

            Button("-") {
                viewModel.zoomScale = max(0.1, viewModel.zoomScale - 0.1)
                baseScale = viewModel.zoomScale
            }

            Text("Zoom: \(Int(viewModel.zoomScale * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("+") {
                viewModel.zoomScale = min(3.0, viewModel.zoomScale + 0.1)
                baseScale = viewModel.zoomScale
            }

            Picker("Theme", selection: $viewModel.theme) {
                ForEach(GraphTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .frame(width: 150)

            Toggle("Hide Omitted", isOn: $viewModel.hideOmittedNodes)
                .toggleStyle(.checkbox)

            Button("Expand All") {
                viewModel.expandAll()
            }

            Button("Reset Layout") {
                viewModel.resetLayout()
            }

            Button("Export PNG") {
                viewModel.exportGraphAsPNG(view: graphContent(scaled: false))
            }

            Button("Export JSON") {
                viewModel.exportAsJSON()
            }

            if let onCompare {
                Button("Compare…") {
                    onCompare()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func setupScrollViewObserver(_ scrollView: NSScrollView) {
        guard nsScrollView !== scrollView else { return }
        nsScrollView = scrollView

        // Remove existing observer if any
        if let observer = boundsObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true

        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { _ in
            viewModel.scrollViewBounds = clipView.bounds
        }

        // Set initial bounds
        viewModel.scrollViewBounds = clipView.bounds
    }

    @ViewBuilder
    private func graphContent(scaled: Bool) -> some View {
        let scale = scaled ? viewModel.zoomScale : 1.0
        ZStack(alignment: .topLeading) {
            // Draw edges
            ForEach(viewModel.visibleEdges) { edge in
                let from = viewModel.edgeStart(for: edge.parentId)
                let to = viewModel.edgeEnd(for: edge.childId)
                GraphEdgeView(
                    from: CGPoint(x: from.x * scale, y: from.y * scale),
                    to: CGPoint(x: to.x * scale, y: to.y * scale),
                    edgeColor: Color(hex: viewModel.theme.edgeColor).opacity(0.5)
                )
            }

            // Draw nodes on top
            ForEach(viewModel.visibleNodePositions, id: \.nodeId) { position in
                if let node = viewModel.nodeMap[position.nodeId] {
                    let size = viewModel.nodeSize(for: position.subtreeSize)
                    let center = viewModel.effectivePosition(for: position.nodeId)
                    GraphNodeView(
                        node: node,
                        fillColor: viewModel.colorForNode(node),
                        isHighlighted: !viewModel.filteredNodes.isEmpty && viewModel.filteredNodes.contains(node.id),
                        isCollapsible: viewModel.hasChildren(node.id),
                        isCollapsed: viewModel.isCollapsed(node.id)
                    )
                    .frame(width: size.width * scale, height: size.height * scale)
                    .position(x: center.x * scale, y: center.y * scale)
                    .onTapGesture(count: 2) {
                        viewModel.toggleCollapse(nodeId: node.id)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                viewModel.moveNode(
                                    id: node.id,
                                    to: CGPoint(
                                        x: value.location.x / scale,
                                        y: value.location.y / scale
                                    )
                                )
                            }
                    )
                }
            }
        }
        .frame(
            width: viewModel.canvasSize.width * scale,
            height: viewModel.canvasSize.height * scale
        )
    }
}
