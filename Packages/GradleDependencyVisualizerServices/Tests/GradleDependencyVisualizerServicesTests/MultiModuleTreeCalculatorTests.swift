import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizerServices

@Suite
struct MultiModuleTreeCalculatorTests {
    @Test
    func assemblesTwoModuleTrees() {
        let appModule = TestDependencyTreeFactory.makeModule(name: "app")
        let coreModule = TestDependencyTreeFactory.makeModule(name: "core")

        let appTree = TestDependencyTreeFactory.makeSimpleTree(projectName: "app")
        let coreTree = TestDependencyTreeFactory.makeSimpleTree(projectName: "core")

        let result = MultiModuleTreeCalculator.assemble(
            projectName: "my-project",
            configuration: .compileClasspath,
            moduleTrees: [(module: appModule, tree: appTree), (module: coreModule, tree: coreTree)]
        )

        #expect(result.roots.count == 2)
        #expect(result.projectName == "my-project")
        #expect(result.configuration == .compileClasspath)
    }

    @Test
    func aggregatesConflictsAcrossModules() {
        let appModule = TestDependencyTreeFactory.makeModule(name: "app")
        let coreModule = TestDependencyTreeFactory.makeModule(name: "core")

        let appTree = TestDependencyTreeFactory.makeTreeWithConflicts(projectName: "app")
        let coreTree = TestDependencyTreeFactory.makeTreeWithConflicts(projectName: "core")

        let result = MultiModuleTreeCalculator.assemble(
            projectName: "my-project",
            configuration: .runtimeClasspath,
            moduleTrees: [(module: appModule, tree: appTree), (module: coreModule, tree: coreTree)]
        )

        #expect(result.conflicts.count == appTree.conflicts.count + coreTree.conflicts.count)
    }

    @Test
    func singleModuleAssembly() {
        let module = TestDependencyTreeFactory.makeModule(name: "app")
        let tree = TestDependencyTreeFactory.makeSimpleTree(projectName: "app")

        let result = MultiModuleTreeCalculator.assemble(
            projectName: "my-project",
            configuration: .compileClasspath,
            moduleTrees: [(module: module, tree: tree)]
        )

        #expect(result.roots.count == 1)
        #expect(result.roots[0].artifact == "app")
        #expect(result.roots[0].children.count == tree.roots.count)
    }

    @Test
    func emptyModulesReturnsEmptyTree() {
        let result = MultiModuleTreeCalculator.assemble(
            projectName: "my-project",
            configuration: .compileClasspath,
            moduleTrees: []
        )

        #expect(result.roots.isEmpty)
        #expect(result.conflicts.isEmpty)
    }

    @Test
    func syntheticNodesHaveCorrectCoordinates() {
        let appModule = TestDependencyTreeFactory.makeModule(name: "app")
        let tree = TestDependencyTreeFactory.makeSimpleTree(projectName: "app")

        let result = MultiModuleTreeCalculator.assemble(
            projectName: "my-project",
            configuration: .compileClasspath,
            moduleTrees: [(module: appModule, tree: tree)]
        )

        let syntheticNode = result.roots[0]
        #expect(syntheticNode.group == "my-project")
        #expect(syntheticNode.artifact == "app")
        #expect(syntheticNode.requestedVersion == "module")
    }
}
