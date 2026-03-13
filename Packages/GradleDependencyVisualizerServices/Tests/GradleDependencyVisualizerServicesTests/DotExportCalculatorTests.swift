import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DotExportCalculatorTests {
    @Test
    func exportContainsDigraphStructure() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let dot = DotExportCalculator.export(tree: tree)
        #expect(dot.contains("digraph dependencies {"))
        #expect(dot.contains("}"))
    }

    @Test
    func exportContainsNodeLabels() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let dot = DotExportCalculator.export(tree: tree)
        #expect(dot.contains("spring-core"))
        #expect(dot.contains("guava"))
    }

    @Test
    func exportHighlightsConflicts() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let dot = DotExportCalculator.export(tree: tree)
        #expect(dot.contains("#ffcccc"))
    }
}
