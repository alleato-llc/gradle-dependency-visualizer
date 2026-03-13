import GradleDependencyVisualizerCore

public protocol GradleRunner: Sendable {
    func runDependencies(
        projectPath: String,
        configuration: GradleConfiguration
    ) async throws -> String
}
