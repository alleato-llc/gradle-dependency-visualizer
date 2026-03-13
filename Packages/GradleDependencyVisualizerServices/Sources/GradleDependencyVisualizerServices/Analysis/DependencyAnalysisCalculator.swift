import GradleDependencyVisualizerCore

public enum DependencyAnalysisCalculator {
    public static func collectConflicts(from tree: DependencyTree) -> [DependencyConflict] {
        tree.conflicts
    }

    public static func conflictsByCoordinate(from tree: DependencyTree) -> [String: [DependencyConflict]] {
        Dictionary(grouping: tree.conflicts, by: \.coordinate)
    }

    public static func allNodes(from tree: DependencyTree) -> [DependencyNode] {
        tree.roots.flatMap { allNodes(from: $0) }
    }

    public static func allNodes(from node: DependencyNode) -> [DependencyNode] {
        [node] + node.children.flatMap { allNodes(from: $0) }
    }

    public static func uniqueCoordinates(from tree: DependencyTree) -> Set<String> {
        Set(allNodes(from: tree).map(\.coordinate))
    }

    public static func subtreeSizes(from tree: DependencyTree) -> [String: Int] {
        var sizes: [String: Int] = [:]
        for node in allNodes(from: tree) {
            let key = node.coordinate
            sizes[key] = max(sizes[key] ?? 0, node.subtreeSize)
        }
        return sizes
    }
}
