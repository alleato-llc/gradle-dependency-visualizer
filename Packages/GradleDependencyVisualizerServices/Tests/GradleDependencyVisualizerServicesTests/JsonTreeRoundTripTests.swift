import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct JsonTreeRoundTripTests {
    @Test
    func exportProducesValidJSON() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JSONDecoder().decode(DependencyTree.self, from: data)
        #expect(decoded.projectName == tree.projectName)
        #expect(decoded.configuration == tree.configuration)
        #expect(decoded.roots.count == tree.roots.count)
    }

    @Test
    func roundTripPreservesNodeHierarchy() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JsonTreeImporter.importTree(from: data)

        let originalRoot = tree.roots[0]
        let decodedRoot = decoded.roots[0]
        #expect(decodedRoot.group == originalRoot.group)
        #expect(decodedRoot.artifact == originalRoot.artifact)
        #expect(decodedRoot.requestedVersion == originalRoot.requestedVersion)
        #expect(decodedRoot.children.count == originalRoot.children.count)
    }

    @Test
    func roundTripPreservesConflicts() throws {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JsonTreeImporter.importTree(from: data)

        #expect(decoded.conflicts.count == tree.conflicts.count)
        let original = tree.conflicts[0]
        let result = decoded.conflicts[0]
        #expect(result.coordinate == original.coordinate)
        #expect(result.requestedVersion == original.requestedVersion)
        #expect(result.resolvedVersion == original.resolvedVersion)
        #expect(result.requestedBy == original.requestedBy)
    }

    @Test
    func roundTripPreservesFlags() throws {
        let node = TestDependencyTreeFactory.makeNode(isOmitted: true, isConstraint: true)
        let tree = DependencyTree(
            projectName: "flags-test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JsonTreeImporter.importTree(from: data)

        #expect(decoded.roots[0].isOmitted == true)
        #expect(decoded.roots[0].isConstraint == true)
    }

    @Test
    func roundTripPreservesResolvedVersion() throws {
        let node = TestDependencyTreeFactory.makeNode(
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0"
        )
        let tree = DependencyTree(
            projectName: "version-test",
            configuration: .runtimeClasspath,
            roots: [node],
            conflicts: []
        )
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JsonTreeImporter.importTree(from: data)

        #expect(decoded.roots[0].resolvedVersion == "2.0.0")
        #expect(decoded.roots[0].requestedVersion == "1.0.0")
    }

    @Test
    func importInvalidDataThrows() {
        let garbage = Data("not json".utf8)
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: garbage)
        }
    }

    @Test
    func exportOutputContainsExpectedKeys() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"projectName\""))
        #expect(json.contains("\"roots\""))
        #expect(json.contains("\"conflicts\""))
        #expect(json.contains("\"configuration\""))
    }

    @Test
    func roundTripDeepTree() throws {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 5)
        let data = try JsonTreeExporter.export(tree: tree)
        let decoded = try JsonTreeImporter.importTree(from: data)

        #expect(decoded.maxDepth == tree.maxDepth)
        #expect(decoded.totalNodeCount == tree.totalNodeCount)
    }
}
