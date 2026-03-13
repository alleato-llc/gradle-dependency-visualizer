import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct GradleTreeTextGeneratorTests {
    // MARK: - Single node

    @Test
    func singleRootUsesBackslashConnector() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0"
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0")
    }

    @Test
    func emptyTreeProducesEmptyString() {
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "")
    }

    // MARK: - Multiple roots

    @Test
    func multipleRootsUsePlusForAllButLast() {
        let a = TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "a", requestedVersion: "1.0")
        let b = TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "b", requestedVersion: "2.0")
        let c = TestDependencyTreeFactory.makeNode(group: "com.c", artifact: "c", requestedVersion: "3.0")
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [a, b, c], conflicts: [])
        let lines = GradleTreeTextGenerator.export(tree: tree).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("+--- "))
        #expect(lines[1].hasPrefix("+--- "))
        #expect(lines[2].hasPrefix("\\--- "))
    }

    // MARK: - Children indentation

    @Test
    func childrenAreIndentedWithPipePrefix() {
        let child = TestDependencyTreeFactory.makeNode(group: "com.child", artifact: "child", requestedVersion: "1.0")
        let sibling = TestDependencyTreeFactory.makeNode(group: "com.sibling", artifact: "sibling", requestedVersion: "2.0")
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.root",
            artifact: "root",
            requestedVersion: "1.0",
            children: [child, sibling]
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [root], conflicts: [])
        let lines = GradleTreeTextGenerator.export(tree: tree).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0] == "\\--- com.root:root:1.0")
        #expect(lines[1] == "     +--- com.child:child:1.0")
        #expect(lines[2] == "     \\--- com.sibling:sibling:2.0")
    }

    @Test
    func nonLastRootChildrenUsePipePrefix() {
        let child = TestDependencyTreeFactory.makeNode(group: "com.child", artifact: "child", requestedVersion: "1.0")
        let root1 = TestDependencyTreeFactory.makeNode(
            group: "com.root1",
            artifact: "root1",
            requestedVersion: "1.0",
            children: [child]
        )
        let root2 = TestDependencyTreeFactory.makeNode(group: "com.root2", artifact: "root2", requestedVersion: "2.0")
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [root1, root2], conflicts: [])
        let lines = GradleTreeTextGenerator.export(tree: tree).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0] == "+--- com.root1:root1:1.0")
        #expect(lines[1] == "|    \\--- com.child:child:1.0")
        #expect(lines[2] == "\\--- com.root2:root2:2.0")
    }

    @Test
    func deepNestingIndentsCorrectly() {
        let c = TestDependencyTreeFactory.makeNode(group: "com.c", artifact: "c", requestedVersion: "3.0")
        let b = TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "b", requestedVersion: "2.0", children: [c])
        let a = TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "a", requestedVersion: "1.0", children: [b])
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [a], conflicts: [])
        let lines = GradleTreeTextGenerator.export(tree: tree).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0] == "\\--- com.a:a:1.0")
        #expect(lines[1] == "     \\--- com.b:b:2.0")
        #expect(lines[2] == "          \\--- com.c:c:3.0")
    }

    // MARK: - Conflict marker

    @Test
    func conflictNodeRendersArrow() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0"
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0 -> 2.0.0")
    }

    // MARK: - Omitted marker

    @Test
    func omittedNodeRendersAsterisk() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0",
            isOmitted: true
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0 (*)")
    }

    // MARK: - Constraint marker

    @Test
    func constraintNodeRendersC() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0",
            isConstraint: true
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0 (c)")
    }

    // MARK: - Combined markers

    @Test
    func conflictWithOmittedRendersBothMarkers() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0",
            isOmitted: true
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0 -> 2.0.0 (*)")
    }

    @Test
    func conflictWithConstraintRendersBothMarkers() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "lib",
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0",
            isConstraint: true
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let text = GradleTreeTextGenerator.export(tree: tree)

        #expect(text == "\\--- com.example:lib:1.0.0 -> 2.0.0 (c)")
    }

    // MARK: - Complex tree structure

    @Test
    func mixedTreeRendersCorrectStructure() {
        let omitted = TestDependencyTreeFactory.makeNode(
            group: "com.omit",
            artifact: "omit",
            requestedVersion: "1.0",
            isOmitted: true
        )
        let conflict = TestDependencyTreeFactory.makeNode(
            group: "com.conflict",
            artifact: "conflict",
            requestedVersion: "1.0",
            resolvedVersion: "2.0"
        )
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.root",
            artifact: "root",
            requestedVersion: "1.0",
            children: [omitted, conflict]
        )
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [root], conflicts: [])
        let lines = GradleTreeTextGenerator.export(tree: tree).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0] == "\\--- com.root:root:1.0")
        #expect(lines[1] == "     +--- com.omit:omit:1.0 (*)")
        #expect(lines[2] == "     \\--- com.conflict:conflict:1.0 -> 2.0")
    }
}
