public struct DependencyTree: Sendable, Equatable {
    public static func == (lhs: DependencyTree, rhs: DependencyTree) -> Bool {
        lhs.projectName == rhs.projectName
            && lhs.configuration == rhs.configuration
            && lhs.totalNodeCount == rhs.totalNodeCount
    }

    public let projectName: String
    public let configuration: GradleConfiguration
    public let roots: [DependencyNode]
    public let conflicts: [DependencyConflict]

    public init(
        projectName: String,
        configuration: GradleConfiguration,
        roots: [DependencyNode],
        conflicts: [DependencyConflict]
    ) {
        self.projectName = projectName
        self.configuration = configuration
        self.roots = roots
        self.conflicts = conflicts
    }

    public var totalNodeCount: Int {
        roots.reduce(0) { $0 + $1.subtreeSize }
    }

    public var maxDepth: Int {
        roots.map { Self.depth(of: $0) }.max() ?? 0
    }

    private static func depth(of node: DependencyNode) -> Int {
        if node.children.isEmpty {
            return 1
        }
        return 1 + node.children.map { depth(of: $0) }.max()!
    }
}
