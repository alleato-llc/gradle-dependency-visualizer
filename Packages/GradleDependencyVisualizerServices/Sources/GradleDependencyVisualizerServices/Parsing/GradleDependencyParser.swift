import GradleDependencyVisualizerCore

public protocol GradleDependencyParser: Sendable {
    func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree
}
