import AppKit
import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

enum ModuleLoadStatus {
    case pending
    case loading
    case loaded
    case failed(String)
}

@Observable @MainActor
final class ProjectSelectionViewModel {
    private let gradleRunner: any GradleRunner
    private let dependencyParser: any GradleDependencyParser
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "ProjectSelection")

    var projectPath: String = ""
    var selectedConfiguration: GradleConfiguration = .compileClasspath
    var isLoading = false
    var dependencyTree: DependencyTree?
    let errorPresenter = ErrorPresenter()

    var discoveredModules: [GradleModule] = []
    var selectedModules: Set<String> = []
    var skippedModules: [String] = []
    var moduleLoadStatus: [String: ModuleLoadStatus] = [:]
    var moduleSearchText: String = ""
    var isMultiModule: Bool { !discoveredModules.isEmpty }

    var filteredModules: [GradleModule] {
        if moduleSearchText.isEmpty {
            return discoveredModules
        }
        return discoveredModules.filter { $0.path.localizedCaseInsensitiveContains(moduleSearchText) }
    }

    var modulesCompleted: Int {
        moduleLoadStatus.values.filter {
            switch $0 {
            case .loaded, .failed: return true
            default: return false
            }
        }.count
    }

    var modulesTotal: Int {
        moduleLoadStatus.count
    }

    var loadSummary: String? {
        guard !skippedModules.isEmpty else { return nil }
        let total = discoveredModules.filter { selectedModules.contains($0.id) }.count
        let loaded = total - skippedModules.count
        return "Loaded \(loaded)/\(total) modules (\(skippedModules.count) skipped)"
    }

    var isShowingError: Bool {
        get { errorPresenter.isShowingError }
        set { if !newValue { errorPresenter.dismiss() } }
    }

    var errorMessage: String { errorPresenter.errorMessage }

    var hasValidProject: Bool {
        !projectPath.isEmpty && FileManager.default.fileExists(atPath: projectPath)
    }

    init(gradleRunner: any GradleRunner, dependencyParser: any GradleDependencyParser) {
        self.gradleRunner = gradleRunner
        self.dependencyParser = dependencyParser
    }

    func selectProjectViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Gradle project directory"

        if panel.runModal() == .OK, let url = panel.url {
            setProjectPath(url.path)
        }
    }

    func setProjectPath(_ path: String) {
        projectPath = path
        discoveredModules = []
        selectedModules = []
        moduleLoadStatus = [:]
        let gradlewPath = (path as NSString).appendingPathComponent("gradlew")
        if !FileManager.default.isExecutableFile(atPath: gradlewPath) {
            errorPresenter.present(GradleDependencyVisualizerError.gradlewNotFound)
            return
        }
        logger.info("Project path set to: \(path)")
    }

    func handleDroppedURL(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }

        if isDir.boolValue {
            setProjectPath(url.path)
            return true
        }

        let filename = url.lastPathComponent
        if filename == "build.gradle" || filename == "build.gradle.kts" {
            setProjectPath(url.deletingLastPathComponent().path)
            return true
        }

        return false
    }

    func importFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, .plainText]
        panel.message = "Select a dependency tree file (JSON or Gradle text output)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let tree = try TreeImporter.importTree(
                from: data,
                fileName: url.lastPathComponent,
                fallbackConfiguration: selectedConfiguration
            )
            dependencyTree = tree
        } catch {
            errorPresenter.present(error)
        }
    }

    func discoverModules() {
        guard hasValidProject else {
            errorPresenter.present(GradleDependencyVisualizerError.invalidProjectPath)
            return
        }

        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                let modules = try await gradleRunner.listProjects(projectPath: projectPath)
                discoveredModules = modules
                selectedModules = Set(modules.map(\.id))
                if modules.isEmpty {
                    logger.info("No submodules found, single-module project")
                } else {
                    logger.info("Discovered \(modules.count) modules")
                }
            } catch {
                logger.error("Failed to discover modules: \(error.localizedDescription)")
                errorPresenter.present(error)
            }
        }
    }

    func loadDependencies() {
        guard hasValidProject else {
            errorPresenter.present(GradleDependencyVisualizerError.invalidProjectPath)
            return
        }

        if isMultiModule {
            loadMultiModuleDependencies()
        } else {
            loadWithAutoDiscovery()
        }
    }

    func toggleSelectAllModules() {
        if selectedModules.count == discoveredModules.count {
            selectedModules.removeAll()
        } else {
            selectedModules = Set(discoveredModules.map(\.id))
        }
    }

    private func loadWithAutoDiscovery() {
        isLoading = true
        dependencyTree = nil

        Task {
            do {
                let modules = try await gradleRunner.listProjects(projectPath: projectPath)
                if !modules.isEmpty {
                    discoveredModules = modules
                    selectedModules = Set(modules.map(\.id))
                    logger.info("Auto-discovered \(modules.count) modules")
                    isLoading = false
                    loadMultiModuleDependencies()
                    return
                }
            } catch {
                logger.info("Module discovery failed, falling back to single-module: \(error.localizedDescription)")
            }
            isLoading = false
            loadSingleModuleDependencies()
        }
    }

    private func loadSingleModuleDependencies() {
        isLoading = true
        dependencyTree = nil

        Task {
            defer { isLoading = false }
            do {
                let output = try await gradleRunner.runDependencies(
                    projectPath: projectPath,
                    configuration: selectedConfiguration
                )
                let projectName = (projectPath as NSString).lastPathComponent
                dependencyTree = dependencyParser.parse(
                    output: output,
                    projectName: projectName,
                    configuration: selectedConfiguration
                )
                logger.info("Loaded \(self.dependencyTree?.totalNodeCount ?? 0) dependencies")
            } catch {
                logger.error("Failed to load dependencies: \(error.localizedDescription)")
                errorPresenter.present(error)
            }
        }
    }

    private func loadMultiModuleDependencies() {
        let modules = discoveredModules.filter { selectedModules.contains($0.id) }
        guard !modules.isEmpty else { return }

        isLoading = true
        dependencyTree = nil
        skippedModules = []
        moduleLoadStatus = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, ModuleLoadStatus.pending) })

        Task {
            defer { isLoading = false }
            let (moduleTrees, skipped) = await loadModulesConcurrently(
                modules,
                onModuleStarted: { [weak self] id in
                    self?.moduleLoadStatus[id] = .loading
                },
                onModuleCompleted: { [weak self] id, status in
                    self?.moduleLoadStatus[id] = status
                }
            )
            skippedModules = skipped
            if moduleTrees.isEmpty {
                errorPresenter.present(GradleDependencyVisualizerError.noModulesLoaded)
                return
            }
            let projectName = (projectPath as NSString).lastPathComponent
            dependencyTree = MultiModuleTreeCalculator.assemble(
                projectName: projectName,
                configuration: selectedConfiguration,
                moduleTrees: moduleTrees
            )
            logger.info("Loaded \(moduleTrees.count)/\(modules.count) modules (\(skipped.count) skipped)")
        }
    }

    private func loadModulesConcurrently(
        _ modules: [GradleModule],
        onModuleStarted: @MainActor @Sendable (String) -> Void,
        onModuleCompleted: @MainActor @Sendable (String, ModuleLoadStatus) -> Void
    ) async -> (loaded: [(module: GradleModule, tree: DependencyTree)], skipped: [String]) {
        let maxConcurrency = 4
        let projectName = (projectPath as NSString).lastPathComponent

        return await withTaskGroup(
            of: (GradleModule, DependencyTree?).self,
            returning: (loaded: [(module: GradleModule, tree: DependencyTree)], skipped: [String]).self
        ) { group in
            var results: [(module: GradleModule, tree: DependencyTree)] = []
            var skipped: [String] = []
            var index = 0

            for module in modules.prefix(maxConcurrency) {
                await onModuleStarted(module.id)
                group.addTask { [projectPath, selectedConfiguration, gradleRunner, dependencyParser, logger] in
                    do {
                        let output = try await gradleRunner.runDependencies(
                            projectPath: projectPath,
                            module: module,
                            configuration: selectedConfiguration
                        )
                        let tree = dependencyParser.parse(
                            output: output,
                            projectName: projectName,
                            configuration: selectedConfiguration
                        )
                        return (module, tree)
                    } catch {
                        logger.warning("Skipping module \(module.path): \(error.localizedDescription)")
                        return (module, nil)
                    }
                }
                index += 1
            }

            for await result in group {
                if let tree = result.1 {
                    results.append((module: result.0, tree: tree))
                    await onModuleCompleted(result.0.id, .loaded)
                } else {
                    skipped.append(result.0.path)
                    await onModuleCompleted(result.0.id, .failed("Failed to load dependencies"))
                }

                if index < modules.count {
                    let nextModule = modules[index]
                    await onModuleStarted(nextModule.id)
                    group.addTask { [projectPath, selectedConfiguration, gradleRunner, dependencyParser, logger] in
                        do {
                            let output = try await gradleRunner.runDependencies(
                                projectPath: projectPath,
                                module: nextModule,
                                configuration: selectedConfiguration
                            )
                            let tree = dependencyParser.parse(
                                output: output,
                                projectName: projectName,
                                configuration: selectedConfiguration
                            )
                            return (nextModule, tree)
                        } catch {
                            logger.warning("Skipping module \(nextModule.path): \(error.localizedDescription)")
                            return (nextModule, nil)
                        }
                    }
                    index += 1
                }
            }

            return (
                loaded: results.sorted { $0.module.path < $1.module.path },
                skipped: skipped.sorted()
            )
        }
    }
}
