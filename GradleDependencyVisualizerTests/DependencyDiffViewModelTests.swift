import Testing
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct DependencyDiffViewModelTests {
    private let fileExporter = TestFileExporter()

    @MainActor
    private func makeViewModel(
        baseline: DependencyTree? = nil,
        current: DependencyTree? = nil
    ) -> DependencyDiffViewModel {
        let baselineTree = baseline ?? DependencyTree(
            projectName: "baseline",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.old", artifact: "removed-lib", requestedVersion: "1.0")],
            conflicts: []
        )
        let currentTree = current ?? DependencyTree(
            projectName: "current",
            configuration: .compileClasspath,
            roots: [
                TestDependencyTreeFactory.makeNode(group: "com.old", artifact: "removed-lib", requestedVersion: "2.0"),
                TestDependencyTreeFactory.makeNode(group: "com.new", artifact: "added-lib", requestedVersion: "1.0"),
            ],
            conflicts: []
        )
        return DependencyDiffViewModel(baseline: baselineTree, current: currentTree, fileExporter: fileExporter)
    }

    @Test @MainActor
    func filterToggleHidesEntries() {
        let viewModel = makeViewModel()
        let allCount = viewModel.filteredEntries.count
        viewModel.showAdded = false
        #expect(viewModel.filteredEntries.count < allCount)
        #expect(viewModel.filteredEntries.allSatisfy { $0.changeKind != .added })
    }

    @Test @MainActor
    func searchFiltersByCoordinate() {
        let viewModel = makeViewModel()
        viewModel.searchText = "added-lib"
        #expect(viewModel.filteredEntries.count == 1)
        #expect(viewModel.filteredEntries.first?.coordinate == "com.new:added-lib")
    }

    @Test @MainActor
    func defaultHidesUnchanged() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyDiffViewModel(baseline: tree, current: tree, fileExporter: fileExporter)
        #expect(!viewModel.showUnchanged)
        #expect(viewModel.filteredEntries.isEmpty)
    }

    @Test @MainActor
    func exportCallsFileExporter() {
        let viewModel = makeViewModel()
        viewModel.exportDiffAsJSON()
        #expect(fileExporter.saveCallCount == 1)
        #expect(fileExporter.savedContentType == .json)
    }

    @Test @MainActor
    func toggleSortReversesSameField() {
        let viewModel = makeViewModel()
        #expect(viewModel.sortAscending)
        viewModel.toggleSort(field: .coordinate)
        #expect(!viewModel.sortAscending)
    }

    @Test @MainActor
    func toggleSortChangesField() {
        let viewModel = makeViewModel()
        viewModel.toggleSort(field: .status)
        #expect(viewModel.sortField == .status)
        #expect(viewModel.sortAscending)
    }
}
