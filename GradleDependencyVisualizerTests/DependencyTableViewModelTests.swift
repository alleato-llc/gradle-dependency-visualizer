import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct DependencyTableViewModelTests {
    private let fileExporter = TestFileExporter()

    @Test @MainActor
    func initComputesFlatEntries() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        #expect(!viewModel.flatEntries.isEmpty)
        #expect(viewModel.flatEntries.count == 3)
    }

    @Test @MainActor
    func defaultTableModeIsFlat() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.tableMode == .flat)
    }

    @Test @MainActor
    func toggleSortReversesSameField() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .coordinate)
        #expect(!viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortChangesField() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .occurrences)
        #expect(viewModel.sortField == .occurrences)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func searchFiltersEntries() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.searchText = "guava"
        #expect(viewModel.displayedFlatEntries.count == 1)
        #expect(viewModel.displayedFlatEntries.first?.artifact == "guava")
    }

    @Test @MainActor
    func showConflictsOnlyFilters() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.showConflictsOnly = true
        let displayed = viewModel.displayedFlatEntries
        let allConflicts = displayed.allSatisfy(\.hasConflict)
        #expect(allConflicts)
        #expect(!displayed.isEmpty)
    }

    @Test @MainActor
    func exportCallsFileExporter() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.exportTableAsJSON()
        #expect(fileExporter.saveCallCount == 1)
        #expect(fileExporter.savedDefaultName?.hasSuffix(".json") == true)
    }
}
