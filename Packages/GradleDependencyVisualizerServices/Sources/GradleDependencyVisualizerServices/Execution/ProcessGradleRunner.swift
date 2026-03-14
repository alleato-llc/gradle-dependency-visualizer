import Foundation
import GradleDependencyVisualizerCore

private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        _data.append(chunk)
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }
}

public struct ProcessGradleRunner: GradleRunner {
    public init() {}

    public func runDependencies(
        projectPath: String,
        configuration: GradleConfiguration
    ) async throws -> String {
        try await runGradle(
            projectPath: projectPath,
            arguments: [
                "dependencies",
                "--configuration", configuration.rawValue,
                "--console=plain",
            ]
        )
    }

    public func listProjects(projectPath: String) async throws -> [GradleModule] {
        let output = try await runGradle(
            projectPath: projectPath,
            arguments: ["projects", "--console=plain"]
        )
        return GradleProjectListParser.parse(output: output)
    }

    public func runDependencies(
        projectPath: String,
        module: GradleModule,
        configuration: GradleConfiguration
    ) async throws -> String {
        try await runGradle(
            projectPath: projectPath,
            arguments: [
                "\(module.path):dependencies",
                "--configuration", configuration.rawValue,
                "--console=plain",
            ]
        )
    }

    public func runDependencyInsight(
        projectPath: String,
        dependency: String,
        configuration: GradleConfiguration
    ) async throws -> String {
        try await runGradle(
            projectPath: projectPath,
            arguments: [
                "dependencyInsight",
                "--dependency", dependency,
                "--configuration", configuration.rawValue,
                "-q",
            ]
        )
    }

    private func runGradle(projectPath: String, arguments: [String]) async throws -> String {
        let gradlewPath = (projectPath as NSString).appendingPathComponent("gradlew")

        guard FileManager.default.isExecutableFile(atPath: gradlewPath) else {
            throw GradleRunnerError.gradlewNotFound(path: gradlewPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gradlewPath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            // Read stdout/stderr eagerly to avoid pipe buffer deadlock.
            // If the process writes more than the pipe buffer (~64KB),
            // it blocks until the reader drains the pipe. Reading inside
            // terminationHandler is too late — the process can't terminate
            // while blocked on a full pipe.
            let stdoutAccumulator = DataAccumulator()
            let stderrAccumulator = DataAccumulator()

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stdoutAccumulator.append(chunk)
                }
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stderrAccumulator.append(chunk)
                }
            }

            process.terminationHandler = { process in
                // Drain any remaining data
                pipe.fileHandleForReading.readabilityHandler = nil
                stdoutAccumulator.append(pipe.fileHandleForReading.readDataToEndOfFile())
                errorPipe.fileHandleForReading.readabilityHandler = nil
                stderrAccumulator.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

                let output = String(data: stdoutAccumulator.data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorOutput = String(data: stderrAccumulator.data, encoding: .utf8) ?? ""
                    continuation.resume(throwing: GradleRunnerError.executionFailed(
                        exitCode: process.terminationStatus,
                        stderr: errorOutput
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GradleRunnerError.launchFailed(underlying: error))
            }
        }
    }
}

public enum GradleRunnerError: Error, LocalizedError {
    case gradlewNotFound(path: String)
    case executionFailed(exitCode: Int32, stderr: String)
    case launchFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .gradlewNotFound(let path):
            "Gradle wrapper not found at \(path)"
        case .executionFailed(let exitCode, let stderr):
            "Gradle exited with code \(exitCode): \(stderr)"
        case .launchFailed(let underlying):
            "Failed to launch Gradle: \(underlying.localizedDescription)"
        }
    }
}
