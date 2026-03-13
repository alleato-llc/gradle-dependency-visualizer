import GradleDependencyVisualizerCore

extension DependencyNode {
    var optionalChildren: [DependencyNode]? {
        children.isEmpty ? nil : children
    }
}
