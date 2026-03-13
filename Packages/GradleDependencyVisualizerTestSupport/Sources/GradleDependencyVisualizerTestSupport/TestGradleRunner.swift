import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

public final class TestGradleRunner: GradleRunner, @unchecked Sendable {
    public var outputToReturn: String = ""
    public var errorToThrow: Error?
    public var runDependenciesCallCount = 0
    public var lastProjectPath: String?
    public var lastConfiguration: GradleConfiguration?

    public init() {}

    public func runDependencies(
        projectPath: String,
        configuration: GradleConfiguration
    ) async throws -> String {
        runDependenciesCallCount += 1
        lastProjectPath = projectPath
        lastConfiguration = configuration

        if let error = errorToThrow {
            throw error
        }

        return outputToReturn
    }
}
