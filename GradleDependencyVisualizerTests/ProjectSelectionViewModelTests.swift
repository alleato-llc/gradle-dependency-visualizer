import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct ProjectSelectionViewModelTests {
    @Test @MainActor
    func initialStateIsEmpty() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        #expect(viewModel.projectPath.isEmpty)
        #expect(viewModel.dependencyTree == nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.discoveredModules.isEmpty)
        #expect(viewModel.selectedModules.isEmpty)
        #expect(!viewModel.isMultiModule)
    }

    @Test @MainActor
    func loadDependenciesWithInvalidPathShowsError() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        viewModel.loadDependencies()
        #expect(viewModel.isShowingError)
    }

    @Test @MainActor
    func hasValidProjectReturnsFalseForEmptyPath() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        #expect(!viewModel.hasValidProject)
    }

    @Test @MainActor
    func listProjectsPopulatesDiscoveredModules() async {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        let modules = [
            GradleModule(name: "app", path: ":app"),
            GradleModule(name: "core", path: ":core"),
        ]
        runner.modulesToReturn = modules

        viewModel.projectPath = NSTemporaryDirectory()
        viewModel.discoverModules()

        // Wait for async task to complete
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.discoveredModules.count == 2)
        #expect(viewModel.selectedModules.count == 2)
        #expect(viewModel.isMultiModule)
        #expect(runner.listProjectsCallCount == 1)
    }

    @Test @MainActor
    func singleModuleBypassesDiscovery() async {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        runner.modulesToReturn = []

        viewModel.projectPath = NSTemporaryDirectory()
        viewModel.discoverModules()

        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.discoveredModules.isEmpty)
        #expect(!viewModel.isMultiModule)
    }

    @Test @MainActor
    func loadDependenciesAutoDiscoversModules() async {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        let modules = [
            GradleModule(name: "app", path: ":app"),
            GradleModule(name: "core", path: ":core"),
        ]
        runner.modulesToReturn = modules
        runner.moduleOutputMap = [
            ":app": "mock app output",
            ":core": "mock core output",
        ]

        let tree = TestDependencyTreeFactory.makeSimpleTree()
        parser.treeToReturn = tree

        viewModel.projectPath = NSTemporaryDirectory()

        // loadDependencies should auto-discover modules and load them
        viewModel.loadDependencies()

        try? await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.isMultiModule)
        #expect(viewModel.discoveredModules.count == 2)
        #expect(viewModel.dependencyTree != nil)
        #expect(runner.listProjectsCallCount == 1)
        #expect(runner.moduleRunCallCount == 2)
    }

    @Test @MainActor
    func loadMultiModuleConcurrently() async {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        let modules = [
            GradleModule(name: "app", path: ":app"),
            GradleModule(name: "core", path: ":core"),
        ]
        runner.modulesToReturn = modules
        runner.moduleOutputMap = [
            ":app": "mock app output",
            ":core": "mock core output",
        ]

        let tree = TestDependencyTreeFactory.makeSimpleTree()
        parser.treeToReturn = tree

        viewModel.projectPath = NSTemporaryDirectory()
        viewModel.discoveredModules = modules
        viewModel.selectedModules = Set(modules.map(\.id))

        viewModel.loadDependencies()

        try? await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.dependencyTree != nil)
        #expect(runner.moduleRunCallCount == 2)
    }
}
