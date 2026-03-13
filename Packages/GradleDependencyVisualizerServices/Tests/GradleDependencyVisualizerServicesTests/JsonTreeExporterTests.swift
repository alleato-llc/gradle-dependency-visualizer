import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct JsonTreeExporterTests {
    @Test
    func exportReturnsValidUTF8() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let string = String(data: data, encoding: .utf8)

        #expect(string != nil)
    }

    @Test
    func exportIsPrettyPrinted() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let string = String(data: data, encoding: .utf8)!

        #expect(string.contains("\n"))
        #expect(string.contains("  "))
    }

    @Test
    func exportHasSortedKeys() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let string = String(data: data, encoding: .utf8)!

        // "artifact" should appear before "children" (sorted)
        let artifactRange = string.range(of: "\"artifact\"")!
        let childrenRange = string.range(of: "\"children\"")!
        #expect(artifactRange.lowerBound < childrenRange.lowerBound)
    }

    @Test
    func exportEncodesProjectName() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree(projectName: "my-special-project")
        let data = try JsonTreeExporter.export(tree: tree)
        let string = String(data: data, encoding: .utf8)!

        #expect(string.contains("my-special-project"))
    }

    @Test
    func exportEncodesConfiguration() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree(configuration: .testRuntimeClasspath)
        let data = try JsonTreeExporter.export(tree: tree)
        let string = String(data: data, encoding: .utf8)!

        #expect(string.contains("testRuntimeClasspath"))
    }

    @Test
    func exportEncodesEmptyConflictsAsArray() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let conflicts = json["conflicts"] as! [Any]

        #expect(conflicts.isEmpty)
    }

    @Test
    func exportEncodesConflictFields() throws {
        let tree = TestDependencyTreeFactory.makeTreeWithConflicts()
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let conflicts = json["conflicts"] as! [[String: Any]]

        #expect(conflicts.count == 1)
        #expect(conflicts[0]["coordinate"] as? String == "com.fasterxml.jackson.core:jackson-databind")
        #expect(conflicts[0]["requestedVersion"] as? String == "2.13.0")
        #expect(conflicts[0]["resolvedVersion"] as? String == "2.14.2")
        #expect(conflicts[0]["requestedBy"] as? String == "org.springframework:spring-web")
    }

    @Test
    func exportOmitsNilResolvedVersion() throws {
        let node = TestDependencyTreeFactory.makeNode(requestedVersion: "1.0.0")
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let roots = json["roots"] as! [[String: Any]]

        #expect(roots[0]["resolvedVersion"] == nil)
    }

    @Test
    func exportIncludesResolvedVersionWhenPresent() throws {
        let node = TestDependencyTreeFactory.makeNode(requestedVersion: "1.0.0", resolvedVersion: "2.0.0")
        let tree = DependencyTree(projectName: "test", configuration: .compileClasspath, roots: [node], conflicts: [])
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let roots = json["roots"] as! [[String: Any]]

        #expect(roots[0]["resolvedVersion"] as? String == "2.0.0")
    }

    @Test
    func exportEncodesChildrenRecursively() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let roots = json["roots"] as! [[String: Any]]
        let children = roots[0]["children"] as! [[String: Any]]

        #expect(children.count == 2)
        #expect(children[0]["artifact"] as? String == "guava")
        #expect(children[1]["artifact"] as? String == "slf4j-api")
    }

    @Test
    func exportEncodesEmptyTree() throws {
        let tree = DependencyTree(projectName: "empty", configuration: .compileClasspath, roots: [], conflicts: [])
        let data = try JsonTreeExporter.export(tree: tree)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["roots"] as! [Any]).isEmpty)
        #expect((json["conflicts"] as! [Any]).isEmpty)
        #expect(json["projectName"] as? String == "empty")
    }
}
