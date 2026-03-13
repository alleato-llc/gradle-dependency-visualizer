import Testing
import Foundation
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct TreeImporterTests {
    @Test
    func importsValidJSON() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JSONEncoder().encode(tree)
        let imported = try TreeImporter.importTree(from: data, fileName: "test.json")
        #expect(imported.totalNodeCount == 3)
        #expect(imported.projectName == "test-project")
    }

    @Test
    func importsGradleTextOutput() throws {
        let text = """
        +--- org.springframework:spring-core:5.3.20
        |    +--- com.google.guava:guava:31.1-jre
        |    \\--- org.slf4j:slf4j-api:1.7.36
        """
        let data = Data(text.utf8)
        let tree = try TreeImporter.importTree(from: data, fileName: "my-app-dependencies.txt")
        #expect(tree.totalNodeCount == 3)
        #expect(tree.projectName == "my-app")
    }

    @Test
    func prefersJSONOverText() throws {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let data = try JSONEncoder().encode(tree)
        let imported = try TreeImporter.importTree(from: data, fileName: "output.txt")
        // Should parse as JSON despite .txt extension
        #expect(imported.projectName == "test-project")
    }

    @Test
    func usesSelectedConfigurationForText() throws {
        let text = "+--- com.example:lib:1.0.0\n"
        let data = Data(text.utf8)
        let tree = try TreeImporter.importTree(
            from: data,
            fileName: "deps.txt",
            fallbackConfiguration: .runtimeClasspath
        )
        #expect(tree.configuration == .runtimeClasspath)
    }

    @Test
    func throwsOnEmptyTextWithNoDeps() {
        let data = Data("no dependency lines here\njust some text\n".utf8)
        #expect(throws: TreeImportError.self) {
            try TreeImporter.importTree(from: data, fileName: "empty.txt")
        }
    }

    @Test
    func throwsOnEmptyData() {
        let data = Data()
        #expect(throws: (any Error).self) {
            try TreeImporter.importTree(from: data, fileName: "empty.json")
        }
    }

    @Test
    func stripsCommonFileNameSuffixes() throws {
        let text = "+--- com.example:lib:1.0.0\n"
        let data = Data(text.utf8)

        let tree1 = try TreeImporter.importTree(from: data, fileName: "myapp-compileClasspath.txt")
        #expect(tree1.projectName == "myapp")

        let tree2 = try TreeImporter.importTree(from: data, fileName: "myapp-runtimeClasspath.txt")
        #expect(tree2.projectName == "myapp")

        let tree3 = try TreeImporter.importTree(from: data, fileName: "myapp.txt")
        #expect(tree3.projectName == "myapp")
    }
}
