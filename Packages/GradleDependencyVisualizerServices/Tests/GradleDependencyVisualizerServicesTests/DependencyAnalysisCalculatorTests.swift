import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DependencyAnalysisCalculatorTests {
    @Test
    func collectsAllNodes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let nodes = DependencyAnalysisCalculator.allNodes(from: tree)
        #expect(nodes.count == 3)
    }

    @Test
    func findsUniqueCoordinates() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let coordinates = DependencyAnalysisCalculator.uniqueCoordinates(from: tree)
        #expect(coordinates.count == 3)
        #expect(coordinates.contains("org.springframework:spring-core"))
    }

    @Test
    func computesSubtreeSizes() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let sizes = DependencyAnalysisCalculator.subtreeSizes(from: tree)
        #expect(sizes["org.springframework:spring-core"] == 3)
        #expect(sizes["com.google.guava:guava"] == 1)
    }

    @Test
    func groupsConflictsByCoordinate() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let grouped = DependencyAnalysisCalculator.conflictsByCoordinate(from: tree)
        #expect(grouped.count == 1)
        #expect(grouped["com.fasterxml.jackson.core:jackson-databind"]?.count == 1)
    }
}
