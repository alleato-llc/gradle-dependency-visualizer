import ArgumentParser
import Foundation
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@main
struct GradleDependencyVisualizerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gradle-dependency-visualizer",
        abstract: "Visualize Gradle dependency trees",
        subcommands: [Graph.self, Conflicts.self]
    )
}

struct Graph: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Output dependency tree in DOT format"
    )

    @Argument(help: "Path to the Gradle project directory")
    var projectPath: String

    @Option(name: .shortAndLong, help: "Gradle configuration to analyze")
    var configuration: String = "compileClasspath"

    func run() async throws {
        guard let config = GradleConfiguration(rawValue: configuration) else {
            throw ValidationError("Unknown configuration: \(configuration). Use one of: \(GradleConfiguration.allCases.map(\.rawValue).joined(separator: ", "))")
        }

        let runner = ProcessGradleRunner()
        let parser = TextGradleDependencyParser()

        let output = try await runner.runDependencies(projectPath: projectPath, configuration: config)
        let projectName = (projectPath as NSString).lastPathComponent
        let tree = parser.parse(output: output, projectName: projectName, configuration: config)
        let dot = DotExportCalculator.export(tree: tree)
        print(dot)
    }
}

struct Conflicts: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Report dependency conflicts"
    )

    @Argument(help: "Path to the Gradle project directory")
    var projectPath: String

    @Option(name: .shortAndLong, help: "Gradle configuration to analyze")
    var configuration: String = "compileClasspath"

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: String = "text"

    func run() async throws {
        guard let config = GradleConfiguration(rawValue: configuration) else {
            throw ValidationError("Unknown configuration: \(configuration)")
        }

        guard let reportFormat = ConflictReportFormat(rawValue: format) else {
            throw ValidationError("Unknown format: \(format). Use 'text' or 'json'.")
        }

        let runner = ProcessGradleRunner()
        let parser = TextGradleDependencyParser()

        let output = try await runner.runDependencies(projectPath: projectPath, configuration: config)
        let projectName = (projectPath as NSString).lastPathComponent
        let tree = parser.parse(output: output, projectName: projectName, configuration: config)
        let report = ConflictReportCalculator.report(tree: tree, format: reportFormat)
        print(report)
    }
}
