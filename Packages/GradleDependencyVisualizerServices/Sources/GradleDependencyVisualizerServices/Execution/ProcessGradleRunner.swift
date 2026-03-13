import Foundation
import GradleDependencyVisualizerCore

public struct ProcessGradleRunner: GradleRunner {
    public init() {}

    public func runDependencies(
        projectPath: String,
        configuration: GradleConfiguration
    ) async throws -> String {
        let gradlewPath = (projectPath as NSString).appendingPathComponent("gradlew")

        guard FileManager.default.isExecutableFile(atPath: gradlewPath) else {
            throw GradleRunnerError.gradlewNotFound(path: gradlewPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gradlewPath)
            process.arguments = [
                "dependencies",
                "--configuration", configuration.rawValue,
                "--console=plain",
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
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
