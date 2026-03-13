import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct TreeLayoutCalculatorTests {
    @Test
    func layoutsSingleNode() {
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode()],
            conflicts: []
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)
        #expect(positions.count == 1)
        #expect(positions[0].y == 0)
    }

    @Test
    func layoutsChildrenAtDeeperY() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let positions = TreeLayoutCalculator.layout(tree: tree)
        #expect(positions.count == 3)

        let rootPosition = positions.first(where: { $0.subtreeSize == 3 })
        let childPositions = positions.filter { $0.subtreeSize == 1 }

        #expect(rootPosition != nil)
        #expect(childPositions.count == 2)

        if let root = rootPosition {
            for child in childPositions {
                #expect(child.y > root.y)
            }
        }
    }

    @Test
    func layoutsDeepTree() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 3)
        let positions = TreeLayoutCalculator.layout(tree: tree)
        #expect(positions.count == 4) // depth 0,1,2,3

        let yValues = positions.map(\.y).sorted()
        for i in 1..<yValues.count {
            #expect(yValues[i] > yValues[i - 1])
        }
    }
}
