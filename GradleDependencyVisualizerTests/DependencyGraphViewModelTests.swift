import Foundation
import Testing
import CoreGraphics
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct DependencyGraphViewModelTests {
    private let fileExporter = TestFileExporter()

    @Test @MainActor
    func initComputesPositions() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        #expect(!viewModel.nodePositions.isEmpty)
        #expect(viewModel.nodeMap.count == 4) // 3 original nodes + synthetic project root
    }

    @Test @MainActor
    func positionMapHasAllNodes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        #expect(viewModel.positionMap.count == viewModel.nodePositions.count)
        for pos in viewModel.nodePositions {
            #expect(viewModel.positionMap[pos.nodeId] != nil)
        }
    }

    @Test @MainActor
    func effectivePositionUsesPositionMap() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        for pos in viewModel.nodePositions {
            let effective = viewModel.effectivePosition(for: pos.nodeId)
            #expect(effective != .zero)
        }
    }

    @Test @MainActor
    func colorForGroupIsConsistent() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let color1 = viewModel.colorForGroup("com.google.guava")
        let color2 = viewModel.colorForGroup("com.google.guava")
        #expect(color1 == color2)
    }

    @Test @MainActor
    func nodeSizeIsUniform() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let small = viewModel.nodeSize(for: 1)
        let large = viewModel.nodeSize(for: 100)
        #expect(small.width == large.width)
        #expect(small.height == large.height)
        #expect(small.width > 0)
        #expect(small.height > 0)
    }

    @Test @MainActor
    func searchFilterReturnsMatchingNodes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        viewModel.searchText = "guava"
        #expect(!viewModel.filteredNodes.isEmpty)

        viewModel.searchText = "nonexistent"
        #expect(viewModel.filteredNodes.isEmpty)
    }

    @Test @MainActor
    func emptySearchReturnsNoFilter() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        viewModel.searchText = ""
        #expect(viewModel.filteredNodes.isEmpty)
    }

    // MARK: - Collapse/Expand Tests

    @Test @MainActor
    func toggleCollapseAddsAndRemovesNodeId() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let rootNode = tree.roots[0]
        viewModel.toggleCollapse(nodeId: rootNode.id)
        #expect(viewModel.isCollapsed(rootNode.id))

        viewModel.toggleCollapse(nodeId: rootNode.id)
        #expect(!viewModel.isCollapsed(rootNode.id))
    }

    @Test @MainActor
    func collapseHidesDescendants() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let rootNode = tree.roots[0]
        let childIds = rootNode.children.map(\.id)

        viewModel.toggleCollapse(nodeId: rootNode.id)

        let visibleIds = Set(viewModel.visibleNodePositions.map(\.nodeId))
        for childId in childIds {
            #expect(!visibleIds.contains(childId))
        }
    }

    @Test @MainActor
    func expandAllClearsCollapsed() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let rootNode = tree.roots[0]
        viewModel.toggleCollapse(nodeId: rootNode.id)
        #expect(!viewModel.collapsedNodeIds.isEmpty)

        viewModel.expandAll()
        #expect(viewModel.collapsedNodeIds.isEmpty)
        #expect(viewModel.hiddenByCollapse.isEmpty)
    }

    @Test @MainActor
    func hasChildrenReturnsCorrectly() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let rootNode = tree.roots[0]
        #expect(viewModel.hasChildren(rootNode.id))

        let leafNode = rootNode.children[0]
        #expect(!viewModel.hasChildren(leafNode.id))
    }

    // MARK: - Depth Limiter Tests

    @Test @MainActor
    func nodeDepthsAreComputed() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 3)
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        #expect(viewModel.maxTreeDepth > 0)
        #expect(viewModel.nodeDepths[viewModel.projectRootId] == 0)
    }

    @Test @MainActor
    func depthLimitFiltersDeepNodes() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 5)
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let allCount = viewModel.visibleNodePositions.count

        viewModel.maxVisibleDepth = 2
        let limitedCount = viewModel.visibleNodePositions.count

        #expect(limitedCount < allCount)
    }

    @Test @MainActor
    func depthLimitNilShowsAll() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 5)
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let allCount = viewModel.visibleNodePositions.count

        viewModel.maxVisibleDepth = 2
        viewModel.maxVisibleDepth = nil

        #expect(viewModel.visibleNodePositions.count == allCount)
    }

    // MARK: - Viewport Culling Tests

    @Test @MainActor
    func viewportCullingFiltersDistantNodes() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 5)
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        let allCount = viewModel.visibleNodePositions.count

        // Set a very small viewport that won't contain all nodes
        viewModel.viewportRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let culledCount = viewModel.visibleNodePositions.count

        #expect(culledCount <= allCount)
    }

    @Test @MainActor
    func viewportNilShowsAllNodes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        viewModel.viewportRect = nil
        let allCount = viewModel.visibleNodePositions.count

        #expect(allCount == viewModel.nodePositions.count)
    }

    // MARK: - Omitted IDs Pre-computed

    @Test @MainActor
    func omittedIdsPrecomputed() {
        let omittedNode = TestDependencyTreeFactory.makeNode(isOmitted: true)
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "root",
            children: [omittedNode]
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [root],
            conflicts: []
        )
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        #expect(viewModel.omittedIds.contains(omittedNode.id))
        #expect(!viewModel.omittedIds.contains(root.id))
    }

    // MARK: - JSON Export Tests

    @Test @MainActor
    func exportAsJSONCallsFileExporter() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let viewModel = DependencyGraphViewModel(tree: tree, fileExporter: fileExporter)

        viewModel.exportAsJSON()

        #expect(fileExporter.saveCallCount == 1)
        #expect(fileExporter.savedContentType == .json)
        let savedData = try #require(fileExporter.savedData)
        let decoded = try JSONDecoder().decode(DependencyTree.self, from: savedData)
        #expect(decoded.projectName == tree.projectName)
    }
}
