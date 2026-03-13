import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DependencyDiffCalculatorTests {
    @Test
    func identicalTreesProduceNoChanges() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let result = DependencyDiffCalculator.diff(baseline: tree, current: tree)
        #expect(result.added.isEmpty)
        #expect(result.removed.isEmpty)
        #expect(result.versionChanged.isEmpty)
        #expect(result.unchanged.count == 3)
    }

    @Test
    func addedDependencyDetected() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0")],
            conflicts: []
        )
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [
                TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0"),
                TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "lib-b", requestedVersion: "2.0"),
            ],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        #expect(result.added.count == 1)
        #expect(result.added.first?.coordinate == "com.b:lib-b")
        #expect(result.added.first?.afterVersion == "2.0")
    }

    @Test
    func removedDependencyDetected() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [
                TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0"),
                TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "lib-b", requestedVersion: "2.0"),
            ],
            conflicts: []
        )
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0")],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        #expect(result.removed.count == 1)
        #expect(result.removed.first?.coordinate == "com.b:lib-b")
        #expect(result.removed.first?.beforeVersion == "2.0")
    }

    @Test
    func versionChangeDetected() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0")],
            conflicts: []
        )
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "2.0")],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        #expect(result.versionChanged.count == 1)
        #expect(result.versionChanged.first?.beforeVersion == "1.0")
        #expect(result.versionChanged.first?.afterVersion == "2.0")
    }

    @Test
    func resolvedVersionUsedForComparison() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0", resolvedVersion: "1.5")],
            conflicts: []
        )
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "2.0", resolvedVersion: "1.5")],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        // Both resolve to 1.5, so should be unchanged
        #expect(result.unchanged.count == 1)
        #expect(result.versionChanged.isEmpty)
    }

    @Test
    func emptyBaselineAllAdded() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [],
            conflicts: []
        )
        let current = TestDependencyTreeFactory.makeSimpleTree()
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        #expect(result.added.count == 3)
        #expect(result.removed.isEmpty)
        #expect(result.unchanged.isEmpty)
    }

    @Test
    func emptyCurrentAllRemoved() {
        let baseline = TestDependencyTreeFactory.makeSimpleTree()
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        #expect(result.removed.count == 3)
        #expect(result.added.isEmpty)
        #expect(result.unchanged.isEmpty)
    }

    @Test
    func duplicateCoordinatesCollapsed() {
        // Same coordinate appearing at multiple positions should produce one entry
        let child = TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0")
        let root1 = TestDependencyTreeFactory.makeNode(group: "com.root", artifact: "root1", requestedVersion: "1.0", children: [child])
        let child2 = TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0", isOmitted: true)
        let root2 = TestDependencyTreeFactory.makeNode(group: "com.root", artifact: "root2", requestedVersion: "1.0", children: [child2])

        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [root1, root2],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: tree, current: tree)
        let libAEntries = result.entries.filter { $0.coordinate == "com.a:lib-a" }
        #expect(libAEntries.count == 1)
    }

    @Test
    func entriesSortedByCoordinate() {
        let baseline = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [],
            conflicts: []
        )
        let current = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [
                TestDependencyTreeFactory.makeNode(group: "org.z", artifact: "z-lib", requestedVersion: "1.0"),
                TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "a-lib", requestedVersion: "1.0"),
                TestDependencyTreeFactory.makeNode(group: "io.m", artifact: "m-lib", requestedVersion: "1.0"),
            ],
            conflicts: []
        )
        let result = DependencyDiffCalculator.diff(baseline: baseline, current: current)
        let coordinates = result.entries.map(\.coordinate)
        #expect(coordinates == coordinates.sorted())
    }
}
