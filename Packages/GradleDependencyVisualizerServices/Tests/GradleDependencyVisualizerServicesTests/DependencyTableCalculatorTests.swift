import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DependencyTableCalculatorTests {
    @Test
    func flatEntriesFromSimpleTree() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        #expect(entries.count == 3)
        let guava = entries.first(where: { $0.artifact == "guava" })
        #expect(guava != nil)
        #expect(guava?.version == "31.1-jre")
        #expect(guava?.occurrenceCount == 1)
    }

    @Test
    func flatEntriesFromTreeWithConflicts() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        let jackson = entries.first(where: { $0.coordinate == "com.fasterxml.jackson.core:jackson-databind" })
        #expect(jackson != nil)
        #expect(jackson?.hasConflict == true)
    }

    @Test
    func flatEntriesUsedBy() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        let guava = entries.first(where: { $0.coordinate == "com.google.guava:guava" })
        #expect(guava?.usedBy.contains("org.springframework:spring-core") == true)
    }

    @Test
    func flatEntriesFromEmptyTree() {
        let tree = DependencyTree(
            projectName: "empty",
            configuration: .compileClasspath,
            roots: [],
            conflicts: []
        )
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        #expect(entries.isEmpty)
    }

    @Test
    func parentMapFromTree() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let parents = DependencyTableCalculator.parentMap(from: tree)
        #expect(parents["com.google.guava:guava"]?.contains("org.springframework:spring-core") == true)
        #expect(parents["org.slf4j:slf4j-api"]?.contains("org.springframework:spring-core") == true)
        #expect(parents["org.springframework:spring-core"] == nil)
    }

    @Test
    func flatEntriesVersionAggregation() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        let jackson = entries.first(where: { $0.coordinate == "com.fasterxml.jackson.core:jackson-databind" })
        #expect(jackson != nil)
        #expect(jackson!.versions.contains("2.13.0"))
        #expect(jackson!.versions.contains("2.14.2"))
    }

    @Test
    func flatEntriesSortedByCoordinate() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let entries = DependencyTableCalculator.flatEntries(from: tree)
        let coordinates = entries.map(\.coordinate)
        #expect(coordinates == coordinates.sorted())
    }
}
