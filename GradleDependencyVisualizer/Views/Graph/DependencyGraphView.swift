import SwiftUI
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

private struct ContentOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

struct DependencyGraphView: View {
    @Bindable var viewModel: DependencyGraphViewModel
    @State private var baseScale: CGFloat = 1.0
    @State private var viewportSize: CGSize = .zero
    @State private var contentOffset: CGPoint = .zero
    @State private var depthSliderValue: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView([.horizontal, .vertical]) {
                graphContent(scaled: true)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ContentOffsetKey.self,
                                value: geo.frame(in: .named("scroll")).origin
                            )
                        }
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ContentOffsetKey.self) { offset in
                contentOffset = offset
                updateViewport()
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        viewportSize = geo.size
                    }
                    .onChange(of: geo.size) { _, newSize in
                        viewportSize = newSize
                        updateViewport()
                    }
                }
            )
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
            depthSliderValue = Double(viewModel.maxTreeDepth)
        }
    }

    private func updateViewport() {
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            viewModel.viewportRect = nil
            return
        }
        let scale = viewModel.zoomScale
        let origin = CGPoint(x: -contentOffset.x / scale, y: -contentOffset.y / scale)
        let size = CGSize(width: viewportSize.width / scale, height: viewportSize.height / scale)
        viewModel.viewportRect = CGRect(origin: origin, size: size)
    }

    private var toolbar: some View {
        HStack {
            TextField("Search dependencies…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
