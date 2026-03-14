import ArgumentParser
import Foundation
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

// MARK: - Main Command

@main
struct GradleDependencyVisualizerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gradle-dependency-visualizer",
        abstract: "Visualize and analyze Gradle dependency trees",
        subcommands: [
            Graph.self,
            Conflicts.self,
            Table.self,
            Validate.self,
            Duplicates.self,
            Diff.self,
            Export.self,
        ]
    )
}

// MARK: - Shared Options

struct ProjectOptions: ParsableArguments {
    @Argument(help: "Path to the Gradle project directory")
    var projectPath: String

    @Option(name: .shortAndLong, help: "Gradle configuration to analyze")
    var configuration: String = "compileClasspath"

    @Option(name: .shortAndLong, help: "Specific module (e.g. :app). Omit for all modules.")
    var module: String?

    @Flag(name: .long, help: "List discovered modules and exit")
    var listModules: Bool = false

    func resolveConfiguration() throws -> GradleConfiguration {
        guard let config = GradleConfiguration(rawValue: configuration) else {
            throw ValidationError("Unknown configuration: \(configuration). Use one of: \(GradleConfiguration.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        return config
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json

    var reportFormat: ReportFormat {
        switch self {
        case .text: .text
        case .json: .json
        }
    }
}

// MARK: - Tree Loading

enum TreeLoader {
    static func printModules(_ modules: [GradleModule]) {
        if modules.isEmpty {
            print("No submodules found (single-module project).")
        } else {
            for m in modules {
                print(m.path)
            }
        }
    }

    static func loadTree(
        options: ProjectOptions,
        runner: ProcessGradleRunner = ProcessGradleRunner(),
        parser: TextGradleDependencyParser = TextGradleDependencyParser()
    ) async throws -> DependencyTree {
        let config = try options.resolveConfiguration()
        let projectName = (options.projectPath as NSString).lastPathComponent

        if let modulePath = options.module {
            let mod = GradleModule(
                name: modulePath.split(separator: ":").last.map(String.init) ?? modulePath,
                path: modulePath
            )
            let output = try await runner.runDependencies(
                projectPath: options.projectPath, module: mod, configuration: config
            )
            return parser.parse(output: output, projectName: projectName, configuration: config)
        }

        let modules = try await runner.listProjects(projectPath: options.projectPath)
        if modules.isEmpty {
            let output = try await runner.runDependencies(
                projectPath: options.projectPath, configuration: config
            )
            return parser.parse(output: output, projectName: projectName, configuration: config)
        }

        var moduleTrees: [(module: GradleModule, tree: DependencyTree)] = []
        for mod in modules {
            do {
                let output = try await runner.runDependencies(
                    projectPath: options.projectPath, module: mod, configuration: config
                )
                let moduleTree = parser.parse(output: output, projectName: mod.name, configuration: config)
                moduleTrees.append((module: mod, tree: moduleTree))
            } catch {
                FileHandle.standardError.write(Data("Warning: skipping module \(mod.path): \(error.localizedDescription)\n".utf8))
            }
        }
        guard !moduleTrees.isEmpty else {
            throw ValidationError("No modules could be loaded for configuration '\(config.rawValue)'")
        }
        return MultiModuleTreeCalculator.assemble(
            projectName: projectName,
            configuration: config,
            moduleTrees: moduleTrees
        )
    }

    /// Resolves an input path to a DependencyTree. If the path is a directory,
    /// runs Gradle to produce the tree. If it's a file, imports it.
    static func resolveTree(
        path: String,
        configuration: String,
        module: String?,
        runner: ProcessGradleRunner = ProcessGradleRunner(),
        parser: TextGradleDependencyParser = TextGradleDependencyParser()
    ) async throws -> DependencyTree {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw ValidationError("Path does not exist: \(path)")
        }

        if isDirectory.boolValue {
            guard let config = GradleConfiguration(rawValue: configuration) else {
                throw ValidationError("Unknown configuration: \(configuration)")
            }
            let projectName = (path as NSString).lastPathComponent

            if let modulePath = module {
                let mod = GradleModule(
                    name: modulePath.split(separator: ":").last.map(String.init) ?? modulePath,
                    path: modulePath
                )
                let output = try await runner.runDependencies(
                    projectPath: path, module: mod, configuration: config
                )
                return parser.parse(output: output, projectName: projectName, configuration: config)
            }

            let modules = try await runner.listProjects(projectPath: path)
            if modules.isEmpty {
                let output = try await runner.runDependencies(
                    projectPath: path, configuration: config
                )
                return parser.parse(output: output, projectName: projectName, configuration: config)
            }

            var moduleTrees: [(module: GradleModule, tree: DependencyTree)] = []
            for mod in modules {
                do {
                    let output = try await runner.runDependencies(
                        projectPath: path, module: mod, configuration: config
                    )
                    let moduleTree = parser.parse(output: output, projectName: mod.name, configuration: config)
                    moduleTrees.append((module: mod, tree: moduleTree))
                } catch {
                    FileHandle.standardError.write(Data("Warning: skipping module \(mod.path): \(error.localizedDescription)\n".utf8))
                }
            }
            guard !moduleTrees.isEmpty else {
                throw ValidationError("No modules could be loaded for configuration '\(config.rawValue)'")
            }
            return MultiModuleTreeCalculator.assemble(
                projectName: projectName,
                configuration: config,
                moduleTrees: moduleTrees
            )
        } else {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let fileName = (path as NSString).lastPathComponent
            guard let config = GradleConfiguration(rawValue: configuration) else {
                throw ValidationError("Unknown configuration: \(configuration)")
            }
            return try TreeImporter.importTree(
                from: data, fileName: fileName, fallbackConfiguration: config
            )
        }
    }

    static func handleListModules(options: ProjectOptions) async throws -> Bool {
        guard options.listModules else { return false }
        let runner = ProcessGradleRunner()
        let modules = try await runner.listProjects(projectPath: options.projectPath)
        printModules(modules)
        return true
    }
}

// MARK: - graph

struct Graph: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Output dependency tree in DOT format"
    )

    @OptionGroup var options: ProjectOptions

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let tree = try await TreeLoader.loadTree(options: options)
        print(DotExportGenerator.export(tree: tree))
    }
}

// MARK: - conflicts

struct Conflicts: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Report dependency conflicts"
    )

    @OptionGroup var options: ProjectOptions

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: OutputFormat = .text

    @Flag(name: .long, help: "Assess conflict risk levels (runs dependencyInsight per conflict)")
    var risk: Bool = false

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let runner = ProcessGradleRunner()
        var tree = try await TreeLoader.loadTree(options: options, runner: runner)
        if risk {
            tree = DependencyTree(
                projectName: tree.projectName,
                configuration: tree.configuration,
                roots: tree.roots,
                conflicts: await ConflictRiskCalculator.assessConflicts(
                    tree: tree, runner: runner, projectPath: options.projectPath
                )
            )
        }
        print(ConflictReportGenerator.report(tree: tree, format: format.reportFormat))
    }
}

// MARK: - table

struct Table: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List dependencies in flat table format"
    )

    @OptionGroup var options: ProjectOptions

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: OutputFormat = .text

    @Flag(name: .long, help: "Show only dependencies with version conflicts")
    var conflictsOnly: Bool = false

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let tree = try await TreeLoader.loadTree(options: options)
        var entries = DependencyTableCalculator.flatEntries(from: tree)
        if conflictsOnly {
            entries = entries.filter(\.hasConflict)
        }
        entries.sort { $0.coordinate < $1.coordinate }
        print(DependencyTableReportGenerator.report(entries: entries, tree: tree, format: format.reportFormat))
    }
}

// MARK: - validate

struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check for test libraries in production dependency scopes"
    )

    @OptionGroup var options: ProjectOptions

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let tree = try await TreeLoader.loadTree(options: options)
        let results = DependencyScopeValidator.validate(tree: tree)
        print(ScopeValidationReportGenerator.report(results: results, tree: tree, format: format.reportFormat))
    }
}

// MARK: - duplicates

struct Duplicates: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Detect duplicate dependencies across or within modules"
    )

    @OptionGroup var options: ProjectOptions

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let runner = ProcessGradleRunner()
        let tree = try await TreeLoader.loadTree(options: options, runner: runner)
        let modules = try await runner.listProjects(projectPath: options.projectPath)
        let results = DuplicateDependencyCalculator.detect(
            tree: tree, projectPath: options.projectPath, modules: modules
        )
        print(DuplicateReportGenerator.report(results: results, tree: tree, format: format.reportFormat))
    }
}

// MARK: - diff

struct Diff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Compare two dependency trees (each can be a project directory or exported file)"
    )

    @Argument(help: "Baseline: path to a Gradle project directory or exported tree file (JSON/text)")
    var baseline: String

    @Argument(help: "Current: path to a Gradle project directory or exported tree file (JSON/text)")
    var current: String

    @Option(name: .shortAndLong, help: "Gradle configuration (applies to project directory inputs)")
    var configuration: String = "compileClasspath"

    @Option(name: .shortAndLong, help: "Specific module (applies to project directory inputs)")
    var module: String?

    @Option(name: .shortAndLong, help: "Output format: text or json")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Filter changes: comma-separated list of added,removed,changed,unchanged")
    var changes: String?

    func run() async throws {
        let baselineTree = try await TreeLoader.resolveTree(
            path: baseline, configuration: configuration, module: module
        )
        let currentTree = try await TreeLoader.resolveTree(
            path: current, configuration: configuration, module: module
        )

        let diffResult = DependencyDiffCalculator.diff(baseline: baselineTree, current: currentTree)
        var entries = diffResult.entries

        if let changes {
            let allowed = Set(changes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
            entries = entries.filter { entry in
                switch entry.changeKind {
                case .added: allowed.contains("added")
                case .removed: allowed.contains("removed")
                case .versionChanged: allowed.contains("changed")
                case .unchanged: allowed.contains("unchanged")
                }
            }
        } else {
            entries = entries.filter { $0.changeKind != .unchanged }
        }

        print(DiffReportGenerator.report(entries: entries, result: diffResult, format: format.reportFormat))
    }
}

// MARK: - export

struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export dependency tree as JSON or Gradle text format"
    )

    @OptionGroup var options: ProjectOptions

    @Option(name: .shortAndLong, help: "Export format: json or text")
    var format: OutputFormat = .json

    func run() async throws {
        if try await TreeLoader.handleListModules(options: options) { return }
        let tree = try await TreeLoader.loadTree(options: options)

        switch format {
        case .json:
            let data = try JsonTreeExporter.export(tree: tree)
            guard let json = String(data: data, encoding: .utf8) else {
                throw ValidationError("Failed to encode tree as JSON")
            }
            print(json)
        case .text:
            print(GradleTreeTextGenerator.export(tree: tree))
        }
    }
}
