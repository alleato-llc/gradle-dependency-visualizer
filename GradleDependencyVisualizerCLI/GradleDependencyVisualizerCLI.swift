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

    @Option(name: .shortAndLong, help: "Specific module (e.g. :app). Omit for all modules.")
    var module: String?

    @Flag(name: .long, help: "List discovered modules and exit")
    var listModules: Bool = false

    func run() async throws {
        guard let config = GradleConfiguration(rawValue: configuration) else {
            throw ValidationError("Unknown configuration: \(configuration). Use one of: \(GradleConfiguration.allCases.map(\.rawValue).joined(separator: ", "))")
        }

        let runner = ProcessGradleRunner()
        let parser = TextGradleDependencyParser()

        if listModules {
            let modules = try await runner.listProjects(projectPath: projectPath)
            if modules.isEmpty {
                print("No submodules found (single-module project).")
            } else {
                for m in modules {
                    print(m.path)
                }
            }
            return
        }

        let tree: DependencyTree
        let projectName = (projectPath as NSString).lastPathComponent

        if let modulePath = module {
            let mod = GradleModule(name: modulePath.split(separator: ":").last.map(String.init) ?? modulePath, path: modulePath)
            let output = try await runner.runDependencies(projectPath: projectPath, module: mod, configuration: config)
            tree = parser.parse(output: output, projectName: projectName, configuration: config)
        } else {
            let modules = try await runner.listProjects(projectPath: projectPath)
            if modules.isEmpty {
                let output = try await runner.runDependencies(projectPath: projectPath, configuration: config)
                tree = parser.parse(output: output, projectName: projectName, configuration: config)
            } else {
                var moduleTrees: [(module: GradleModule, tree: DependencyTree)] = []
                for mod in modules {
                    let output = try await runner.runDependencies(projectPath: projectPath, module: mod, configuration: config)
                    let moduleTree = parser.parse(output: output, projectName: mod.name, configuration: config)
                    moduleTrees.append((module: mod, tree: moduleTree))
                }
                tree = MultiModuleTreeCalculator.assemble(
                    projectName: projectName,
                    configuration: config,
                    moduleTrees: moduleTrees
                )
            }
        }

        let dot = DotExportGenerator.export(tree: tree)
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

    @Option(name: .shortAndLong, help: "Specific module (e.g. :app). Omit for all modules.")
    var module: String?

    @Flag(name: .long, help: "List discovered modules and exit")
    var listModules: Bool = false

    func run() async throws {
        guard let config = GradleConfiguration(rawValue: configuration) else {
            throw ValidationError("Unknown configuration: \(configuration)")
        }

        guard let reportFormat = ConflictReportFormat(rawValue: format) else {
            throw ValidationError("Unknown format: \(format). Use 'text' or 'json'.")
        }

        let runner = ProcessGradleRunner()
        let parser = TextGradleDependencyParser()

        if listModules {
            let modules = try await runner.listProjects(projectPath: projectPath)
            if modules.isEmpty {
                print("No submodules found (single-module project).")
            } else {
                for m in modules {
                    print(m.path)
                }
            }
            return
        }

        let tree: DependencyTree
        let projectName = (projectPath as NSString).lastPathComponent

        if let modulePath = module {
            let mod = GradleModule(name: modulePath.split(separator: ":").last.map(String.init) ?? modulePath, path: modulePath)
            let output = try await runner.runDependencies(projectPath: projectPath, module: mod, configuration: config)
            tree = parser.parse(output: output, projectName: projectName, configuration: config)
        } else {
            let modules = try await runner.listProjects(projectPath: projectPath)
            if modules.isEmpty {
                let output = try await runner.runDependencies(projectPath: projectPath, configuration: config)
                tree = parser.parse(output: output, projectName: projectName, configuration: config)
            } else {
                var moduleTrees: [(module: GradleModule, tree: DependencyTree)] = []
                for mod in modules {
                    let output = try await runner.runDependencies(projectPath: projectPath, module: mod, configuration: config)
                    let moduleTree = parser.parse(output: output, projectName: mod.name, configuration: config)
                    moduleTrees.append((module: mod, tree: moduleTree))
                }
                tree = MultiModuleTreeCalculator.assemble(
                    projectName: projectName,
                    configuration: config,
                    moduleTrees: moduleTrees
                )
            }
        }

        let report = ConflictReportGenerator.report(tree: tree, format: reportFormat)
        print(report)
    }
}
