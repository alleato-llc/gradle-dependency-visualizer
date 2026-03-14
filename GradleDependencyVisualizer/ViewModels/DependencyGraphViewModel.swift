import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class DependencyGraphViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "DependencyGraph")
    private let fileExporter: any FileExporter

    struct Edge: Identifiable {
        let id: String
        let parentId: String
        let childId: String
    }

    let tree: DependencyTree
    let nodePositions: [NodePosition]
    let positionMap: [String: NodePosition]
    let nodeMap: [String: DependencyNode]
    let edges: [Edge]
    let canvasSize: CGSize
    let projectRootId: String
    let omittedIds: Set<String>
    let childrenMap: [String: [String]]
    let nodeDepths: [String: Int]
    let maxTreeDepth: Int

    var zoomScale: CGFloat = 1.0
    var searchText: String = ""
    var positionOverrides: [String: CGPoint] = [:]
    var hideOmittedNodes: Bool = false
    var theme: GraphTheme = .pastel
    var maxVisibleDepth: Int? = nil

    var collapsedNodeIds: Set<String> = [] {
        didSet { recomputeHiddenByCollapse() }
    }
    private(set) var hiddenByCollapse: Set<String> = []

    var focusedMatchIndex: Int = 0

    var filteredNodes: Set<String> {
        guard !searchText.isEmpty else { return Set() }
        let query = searchText.lowercased()
        return Set(
            nodeMap.values
                .filter { $0.coordinate.lowercased().contains(query) }
                .map(\.id)
        )
    }

    var sortedMatchIds: [String] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return nodePositions
            .filter { pos in
                guard let node = nodeMap[pos.nodeId] else { return false }
                return node.coordinate.lowercased().contains(query)
            }
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .map(\.nodeId)
    }

    var focusedMatchId: String? {
        let matches = sortedMatchIds
        guard !matches.isEmpty else { return nil }
        let index = focusedMatchIndex % matches.count
        return matches[index]
    }

    func focusNextMatch() {
        let count = sortedMatchIds.count
        guard count > 0 else { return }
        focusedMatchIndex = (focusedMatchIndex + 1) % count
    }

    func focusPreviousMatch() {
        let count = sortedMatchIds.count
        guard count > 0 else { return }
        focusedMatchIndex = (focusedMatchIndex - 1 + count) % count
    }

    init(tree: DependencyTree, fileExporter: any FileExporter) {
        self.tree = tree
        self.fileExporter = fileExporter

        let computedPositions = TreeLayoutCalculator.layout(tree: tree)

        var map: [String: DependencyNode] = [:]
        var edgeList: [Edge] = []
        var children: [String: [String]] = [:]
        var depths: [String: Int] = [:]

        func collectNodes(_ node: DependencyNode, depth: Int) {
            map[node.id] = node
            depths[node.id] = depth
            var childIds: [String] = []
            for child in node.children {
                edgeList.append(Edge(id: "\(node.id)->\(child.id)", parentId: node.id, childId: child.id))
                childIds.append(child.id)
                collectNodes(child, depth: depth + 1)
            }
            children[node.id] = childIds
        }
        tree.roots.forEach { collectNodes($0, depth: 1) }

        let projectRoot = DependencyNode(
            group: tree.projectName,
            artifact: tree.projectName,
            requestedVersion: tree.configuration.rawValue
        )
        self.projectRootId = projectRoot.id
        map[projectRoot.id] = projectRoot
        depths[projectRoot.id] = 0

        var rootChildIds: [String] = []
        for root in tree.roots {
            edgeList.append(Edge(id: "\(projectRoot.id)->\(root.id)", parentId: projectRoot.id, childId: root.id))
            rootChildIds.append(root.id)
        }
        children[projectRoot.id] = rootChildIds

        self.nodeMap = map
        self.edges = edgeList
        self.childrenMap = children
        self.nodeDepths = depths
        self.maxTreeDepth = depths.values.max() ?? 0
        self.omittedIds = Set(map.values.filter(\.isOmitted).map(\.id))

        let verticalSpacing: Double = 150
        var shiftedPositions = computedPositions.map { pos in
            NodePosition(nodeId: pos.nodeId, x: pos.x, y: pos.y + verticalSpacing, subtreeSize: pos.subtreeSize)
        }

        let rootPositions = shiftedPositions.filter { pos in
            tree.roots.contains(where: { $0.id == pos.nodeId })
        }
        let rootWidth = TreeLayoutCalculator.nodeWidth(for: 1)
        // Position project root above the first root node so it's visible
        // at the initial scroll position (top-left)
        let centerX: Double
        if let firstRootPos = rootPositions.first {
            let firstRootWidth = TreeLayoutCalculator.nodeWidth(for: firstRootPos.subtreeSize)
            centerX = firstRootPos.x + firstRootWidth / 2 - rootWidth / 2
        } else {
            centerX = 0
        }

        let rootPosition = NodePosition(
            nodeId: projectRoot.id,
            x: centerX,
            y: 0,
            subtreeSize: 1
        )
        shiftedPositions.append(rootPosition)

        self.nodePositions = shiftedPositions

        var pMap: [String: NodePosition] = [:]
        for pos in shiftedPositions {
            pMap[pos.nodeId] = pos
        }
        self.positionMap = pMap

        let positions = self.nodePositions
        let maxX = positions.map(\.x).max() ?? 0
        let maxY = positions.map(\.y).max() ?? 0
        self.canvasSize = CGSize(width: maxX + 300, height: maxY + 200)

        logger.info("Graph layout computed: \(positions.count) nodes")
    }

    private func recomputeHiddenByCollapse() {
        var hidden = Set<String>()
        for collapsedId in collapsedNodeIds {
            var queue = childrenMap[collapsedId] ?? []
            while !queue.isEmpty {
                let nodeId = queue.removeFirst()
                if hidden.insert(nodeId).inserted {
                    queue.append(contentsOf: childrenMap[nodeId] ?? [])
                }
            }
        }
        hiddenByCollapse = hidden
    }

    func toggleCollapse(nodeId: String) {
        if collapsedNodeIds.contains(nodeId) {
            collapsedNodeIds.remove(nodeId)
        } else {
            collapsedNodeIds.insert(nodeId)
        }
    }

    func expandAll() {
        collapsedNodeIds.removeAll()
    }

    func hasChildren(_ nodeId: String) -> Bool {
        guard let kids = childrenMap[nodeId] else { return false }
        return !kids.isEmpty
    }

    func isCollapsed(_ nodeId: String) -> Bool {
        collapsedNodeIds.contains(nodeId)
    }

    func colorForGroup(_ group: String) -> String {
        let colors = theme.nodeColors
        let index = abs(group.hashValue) % colors.count
        return colors[index]
    }

    func colorForNode(_ node: DependencyNode) -> String {
        if node.hasConflict {
            return theme.conflictNodeColor
        }
        if node.id == projectRootId {
            return theme.rootNodeColor
        }
        if node.isOmitted {
            return theme.omittedNodeColor
        }
        return colorForGroup(node.group)
    }

    var visibleNodePositions: [NodePosition] {
        nodePositions.filter { pos in
            if hideOmittedNodes && omittedIds.contains(pos.nodeId) { return false }
            if hiddenByCollapse.contains(pos.nodeId) { return false }
            if let maxDepth = maxVisibleDepth, let depth = nodeDepths[pos.nodeId], depth > maxDepth { return false }
            return true
        }
    }

    var visibleEdges: [Edge] {
        let visibleIds = Set(visibleNodePositions.map(\.nodeId))
        return edges.filter { visibleIds.contains($0.parentId) && visibleIds.contains($0.childId) }
    }

    func nodeSize(for subtreeSize: Int) -> CGSize {
        let width = TreeLayoutCalculator.nodeWidth(for: subtreeSize)
        let height = TreeLayoutCalculator.nodeHeight(for: subtreeSize)
        return CGSize(width: width, height: height)
    }

    func effectivePosition(for nodeId: String) -> CGPoint {
        if let override = positionOverrides[nodeId] {
            return override
        }
        guard let pos = positionMap[nodeId] else {
            return .zero
        }
        let size = nodeSize(for: pos.subtreeSize)
        return CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2)
    }

    func moveNode(id: String, to point: CGPoint) {
        positionOverrides[id] = point
    }

    func resetLayout() {
        positionOverrides.removeAll()
    }

    func subtreeSize(for nodeId: String) -> Int {
        positionMap[nodeId]?.subtreeSize ?? 1
    }

    func edgeStart(for nodeId: String) -> CGPoint {
        let center = effectivePosition(for: nodeId)
        let size = nodeSize(for: subtreeSize(for: nodeId))
        return CGPoint(x: center.x, y: center.y + size.height / 2)
    }

    func edgeEnd(for nodeId: String) -> CGPoint {
        let center = effectivePosition(for: nodeId)
        let size = nodeSize(for: subtreeSize(for: nodeId))
        return CGPoint(x: center.x, y: center.y - size.height / 2)
    }

    func exportAsJSON() {
        do {
            let data = try JsonTreeExporter.export(tree: tree)
            try fileExporter.saveData(data, defaultName: "\(tree.projectName)-dependencies.json", contentType: .json)
        } catch {
            logger.error("Failed to export JSON: \(error.localizedDescription)")
        }
    }

    func exportGraphAsPNG(view: some View) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else { return }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }

        do {
            try fileExporter.saveImageData(pngData, defaultName: "\(tree.projectName)-dependencies.png")
            logger.info("Graph exported successfully")
        } catch {
            logger.error("Failed to export graph: \(error.localizedDescription)")
        }
    }
}
