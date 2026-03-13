import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct ConflictReportCalculatorTests {
    @Test
    func textReportShowsNoConflictsMessage() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let report = ConflictReportCalculator.report(tree: tree, format: .text)
        #expect(report.contains("No dependency conflicts found"))
    }

    @Test
    func textReportShowsConflictDetails() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let report = ConflictReportCalculator.report(tree: tree, format: .text)
        #expect(report.contains("jackson-databind"))
        #expect(report.contains("2.13.0"))
        #expect(report.contains("2.14.2"))
        #expect(report.contains("spring-web"))
    }

    @Test
    func jsonReportContainsRequiredFields() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let report = ConflictReportCalculator.report(tree: tree, format: .json)
        #expect(report.contains("\"conflictCount\""))
        #expect(report.contains("\"conflicts\""))
        #expect(report.contains("\"coordinate\""))
    }

    @Test
    func jsonReportForNoConflicts() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let report = ConflictReportCalculator.report(tree: tree, format: .json)
        #expect(report.contains("\"conflictCount\" : 0"))
    }
}
