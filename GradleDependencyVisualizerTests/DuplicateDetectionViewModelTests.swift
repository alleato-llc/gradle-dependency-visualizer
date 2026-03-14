import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct DuplicateDetectionViewModelTests {
    private let fileExporter = TestFileExporter()

    @Test @MainActor
    func detectLoadsResults() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        #expect(viewModel.results.isEmpty)
        viewModel.detect()
        #expect(!viewModel.results.isEmpty)
    }

    @Test @MainActor
    func defaultSortFieldIsCoordinate() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        #expect(viewModel.sortField == .coordinate)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortReversesSameField() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        viewModel.toggleSort(field: .coordinate)
        #expect(!viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortChangesField() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        viewModel.toggleSort(field: .kind)
        #expect(viewModel.sortField == .kind)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func emptyResultsForSingleModule() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        viewModel.detect()
        #expect(viewModel.results.isEmpty)
    }

    @Test @MainActor
    func exportCallsFileExporter() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let viewModel = DuplicateDetectionViewModel(
            tree: tree, fileExporter: fileExporter, projectPath: "/tmp/test"
        )
        viewModel.detect()
        viewModel.exportAsJSON()
        #expect(fileExporter.saveCallCount == 1)
        #expect(fileExporter.savedDefaultName?.hasSuffix(".json") == true)
    }
}
