import GradleDependencyVisualizerCore

public protocol GradleRunner: Sendable {
    func runDependencies(
        projectPath: String,
        configuration: GradleConfiguration
    ) async throws -> String

    func listProjects(projectPath: String) async throws -> [GradleModule]

    func runDependencies(
        projectPath: String,
        module: GradleModule,
        configuration: GradleConfiguration
    ) async throws -> String
}

extension GradleRunner {
    public func listProjects(projectPath: String) async throws -> [GradleModule] {
        []
    }

    public func runDependencies(
        projectPath: String,
        module: GradleModule,
        configuration: GradleConfiguration
    ) async throws -> String {
        try await runDependencies(projectPath: projectPath, configuration: configuration)
    }
}
