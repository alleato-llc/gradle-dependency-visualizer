import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct ScopeValidationViewModelTests {
    private let fileExporter = TestFileExporter()

    @Test @MainActor
    func initLoadsResults() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        #expect(!viewModel.results.isEmpty)
    }

    @Test @MainActor
    func defaultSortFieldIsMatchedLibrary() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.sortField == .matchedLibrary)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortReversesSameField() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .matchedLibrary)
        #expect(!viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortChangesField() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .coordinate)
        #expect(viewModel.sortField == .coordinate)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func emptyResultsForTestConfiguration() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries(configuration: .testCompileClasspath)
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.results.isEmpty)
    }

    @Test @MainActor
    func exportCallsFileExporter() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let viewModel = ScopeValidationViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.exportAsJSON()
        #expect(fileExporter.saveCallCount == 1)
        #expect(fileExporter.savedDefaultName?.hasSuffix(".json") == true)
    }
}
