import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct GradleTreeTextRoundTripTests {
    let parser = TextGradleDependencyParser()

    // MARK: - ASCII render → parse round-trip

    @Test
    func simpleTreeSurvivesTextRoundTrip() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let text = GradleTreeTextGenerator.export(tree: tree)
        let parsed = parser.parse(output: text, projectName: tree.projectName, configuration: tree.configuration)

        #expect(parsed.roots.count == tree.roots.count)
        #expect(parsed.roots[0].group == tree.roots[0].group)
        #expect(parsed.roots[0].artifact == tree.roots[0].artifact)
        #expect(parsed.roots[0].children.count == tree.roots[0].children.count)
    }

    @Test
    func deepTreeSurvivesTextRoundTrip() {
        let tree = TestDependencyTreeFactory.makeDeepTree(depth: 5)
        let text = GradleTreeTextGenerator.export(tree: tree)
        let parsed = parser.parse(output: text, projectName: tree.projectName, configuration: tree.configuration)

        #expect(parsed.totalNodeCount == tree.totalNodeCount)
        #expect(parsed.maxDepth == tree.maxDepth)
    }

    @Test
    func conflictTreeSurvivesTextRoundTrip() {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let text = GradleTreeTextGenerator.export(tree: tree)
        let parsed = parser.parse(output: text, projectName: tree.projectName, configuration: tree.configuration)

        #expect(parsed.conflicts.count == tree.conflicts.count)
        #expect(parsed.conflicts[0].coordinate == tree.conflicts[0].coordinate)
        #expect(parsed.conflicts[0].requestedVersion == tree.conflicts[0].requestedVersion)
        #expect(parsed.conflicts[0].resolvedVersion == tree.conflicts[0].resolvedVersion)
    }

    @Test
    func omittedFlagSurvivesTextRoundTrip() {
        let node = TestDependencyTreeFactory.makeNode(isOmitted: true)
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let text = GradleTreeTextGenerator.export(tree: tree)
        let parsed = parser.parse(output: text, projectName: "test", configuration: .compileClasspath)

        #expect(parsed.roots[0].isOmitted == true)
    }

    @Test
    func constraintFlagSurvivesTextRoundTrip() {
        let node = TestDependencyTreeFactory.makeNode(isConstraint: true)
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let text = GradleTreeTextGenerator.export(tree: tree)
        let parsed = parser.parse(output: text, projectName: "test", configuration: .compileClasspath)

        #expect(parsed.roots[0].isConstraint == true)
    }

    // MARK: - Full pipeline: build → ASCII → parse → JSON → import → verify

    @Test
    func simpleTreeSurvivesFullPipeline() throws {
        let original = TestDependencyTreeFactory.makeSimpleTree()

        // build → ASCII → parse
        let text = GradleTreeTextGenerator.export(tree: original)
        let parsed = parser.parse(output: text, projectName: original.projectName, configuration: original.configuration)

        // parse → JSON → import
        let json = try JsonTreeExporter.export(tree: parsed)
        let imported = try JsonTreeImporter.importTree(from: json)

        #expect(imported.projectName == original.projectName)
        #expect(imported.configuration == original.configuration)
        #expect(imported.roots.count == original.roots.count)
        #expect(imported.roots[0].group == original.roots[0].group)
        #expect(imported.roots[0].artifact == original.roots[0].artifact)
        #expect(imported.roots[0].children.count == original.roots[0].children.count)
    }

    @Test
    func conflictTreeSurvivesFullPipeline() throws {
        let original = TestDependencyTreeFactory.makeTreeWithConflicts()

        let text = GradleTreeTextGenerator.export(tree: original)
        let parsed = parser.parse(output: text, projectName: original.projectName, configuration: original.configuration)
        let json = try JsonTreeExporter.export(tree: parsed)
        let imported = try JsonTreeImporter.importTree(from: json)

        #expect(imported.conflicts.count == original.conflicts.count)
        let orig = original.conflicts[0]
        let result = imported.conflicts[0]
        #expect(result.coordinate == orig.coordinate)
        #expect(result.requestedVersion == orig.requestedVersion)
        #expect(result.resolvedVersion == orig.resolvedVersion)
    }

    @Test
    func deepTreeSurvivesFullPipeline() throws {
        let original = TestDependencyTreeFactory.makeDeepTree(depth: 5)

        let text = GradleTreeTextGenerator.export(tree: original)
        let parsed = parser.parse(output: text, projectName: original.projectName, configuration: original.configuration)
        let json = try JsonTreeExporter.export(tree: parsed)
        let imported = try JsonTreeImporter.importTree(from: json)

        #expect(imported.totalNodeCount == original.totalNodeCount)
        #expect(imported.maxDepth == original.maxDepth)
    }

    @Test
    func multiRootTreeSurvivesFullPipeline() throws {
        let roots = [
            TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a", requestedVersion: "1.0"),
            TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "lib-b", requestedVersion: "2.0"),
            TestDependencyTreeFactory.makeNode(group: "com.c", artifact: "lib-c", requestedVersion: "3.0"),
        ]
        let original = DependencyTree(
            projectName: "multi-root",
            configuration: .runtimeClasspath,
            roots: roots,
            conflicts: []
        )

        let text = GradleTreeTextGenerator.export(tree: original)
        let parsed = parser.parse(output: text, projectName: original.projectName, configuration: original.configuration)
        let json = try JsonTreeExporter.export(tree: parsed)
        let imported = try JsonTreeImporter.importTree(from: json)

        #expect(imported.roots.count == 3)
        #expect(imported.roots[0].group == "com.a")
        #expect(imported.roots[1].group == "com.b")
        #expect(imported.roots[2].group == "com.c")
    }

    @Test
    func allFlagsSurviveFullPipeline() throws {
        let conflictChild = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "conflict-lib",
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0"
        )
        let omittedChild = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "omitted-lib",
            requestedVersion: "3.0.0",
            isOmitted: true
        )
        let constraintChild = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "constraint-lib",
            requestedVersion: "4.0.0",
            isConstraint: true
        )
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "root",
            requestedVersion: "1.0.0",
            children: [conflictChild, omittedChild, constraintChild]
        )
        let conflict = DependencyConflict(
            coordinate: "com.example:conflict-lib",
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0",
            requestedBy: "com.example:root"
        )
        let original = DependencyTree(
            projectName: "flags-test",
            configuration: .compileClasspath,
            roots: [root],
            conflicts: [conflict]
        )

        let text = GradleTreeTextGenerator.export(tree: original)
        let parsed = parser.parse(output: text, projectName: original.projectName, configuration: original.configuration)
        let json = try JsonTreeExporter.export(tree: parsed)
        let imported = try JsonTreeImporter.importTree(from: json)

        let importedRoot = imported.roots[0]
        #expect(importedRoot.children.count == 3)

        // Conflict
        #expect(importedRoot.children[0].resolvedVersion == "2.0.0")
        #expect(importedRoot.children[0].requestedVersion == "1.0.0")
        #expect(imported.conflicts.count == 1)
        #expect(imported.conflicts[0].coordinate == "com.example:conflict-lib")

        // Omitted
        #expect(importedRoot.children[1].isOmitted == true)

        // Constraint
        #expect(importedRoot.children[2].isConstraint == true)
    }

    // MARK: - GradleTreeTextGenerator output format

    @Test
    func exportProducesValidGradleFormat() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text.contains("+--- ") || text.contains("\\--- "))
        #expect(text.contains("org.springframework:spring-core:5.3.20"))
        #expect(text.contains("com.google.guava:guava:31.1-jre"))
    }

    @Test
    func exportRendersConflictArrow() {
        let node = TestDependencyTreeFactory.makeNode(
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0"
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text.contains("1.0.0 -> 2.0.0"))
    }
}
