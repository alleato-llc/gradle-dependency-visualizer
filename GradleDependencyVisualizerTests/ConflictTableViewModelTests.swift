import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct ConflictTableViewModelTests {
    private let fileExporter = TestFileExporter()

    @Test @MainActor
    func initLoadsConflicts() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let viewModel = ConflictTableViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.conflicts.count == 1)
    }

    @Test @MainActor
    func sortedConflictsDefaultsByCoordinate() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let viewModel = ConflictTableViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.sortField == .coordinate)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortReversesSameField() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let viewModel = ConflictTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .coordinate)
        #expect(!viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortChangesField() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let viewModel = ConflictTableViewModel(tree: tree, fileExporter: fileExporter)
        viewModel.toggleSort(field: .resolvedVersion)
        #expect(viewModel.sortField == .resolvedVersion)
        #expect(viewModel.sortAscending)
    }

    @Test @MainActor
    func emptyConflictsTree() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = ConflictTableViewModel(tree: tree, fileExporter: fileExporter)
        #expect(viewModel.conflicts.isEmpty)
        #expect(viewModel.sortedConflicts.isEmpty)
    }
}
