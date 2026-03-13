import AppKit
import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

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

    func loadDependencies() {
        guard hasValidProject else {
            errorPresenter.present(GradleDependencyVisualizerError.invalidProjectPath)
            return
        }

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
}
