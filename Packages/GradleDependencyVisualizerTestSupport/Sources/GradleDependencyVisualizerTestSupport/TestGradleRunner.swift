import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

public final class TestGradleRunner: GradleRunner, @unchecked Sendable {
    public var outputToReturn: String = ""
    public var errorToThrow: Error?
    public var runDependenciesCallCount = 0
    public var lastProjectPath: String?
    public var lastConfiguration: GradleConfiguration?

    public var modulesToReturn: [GradleModule] = []
    public var listProjectsCallCount = 0
    public var moduleOutputMap: [String: String] = [:]
    public var moduleRunCallCount = 0
    public var lastModule: GradleModule?

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

    public func listProjects(projectPath: String) async throws -> [GradleModule] {
        listProjectsCallCount += 1
        lastProjectPath = projectPath

        if let error = errorToThrow {
            throw error
        }

        return modulesToReturn
    }

    public func runDependencies(
        projectPath: String,
        module: GradleModule,
        configuration: GradleConfiguration
    ) async throws -> String {
        moduleRunCallCount += 1
        lastProjectPath = projectPath
        lastModule = module
        lastConfiguration = configuration

        if let error = errorToThrow {
            throw error
        }

        return moduleOutputMap[module.path] ?? outputToReturn
    }
}
