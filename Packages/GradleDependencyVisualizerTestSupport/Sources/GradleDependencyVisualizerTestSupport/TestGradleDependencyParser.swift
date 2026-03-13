import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

public final class TestGradleDependencyParser: GradleDependencyParser, @unchecked Sendable {
    public var treeToReturn: DependencyTree?
    public var parseCallCount = 0
    public var lastOutput: String?

    public init() {}

    public func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree {
        parseCallCount += 1
        lastOutput = output

        if let tree = treeToReturn {
            return tree
        }

        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [],
            conflicts: []
        )
    }
}
