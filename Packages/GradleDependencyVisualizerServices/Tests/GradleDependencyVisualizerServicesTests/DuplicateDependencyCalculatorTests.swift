import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DuplicateDependencyCalculatorTests {
    @Test
    func crossModuleSharedDep() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree()
        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        #expect(results.count == 1)
        #expect(results[0].coordinate == "com.google.guava:guava")
        #expect(results[0].kind == .crossModule)
        #expect(results[0].modules.count == 2)
    }

    @Test
    func crossModuleUniqueDeps() {
        let moduleA = TestDependencyTreeFactory.makeNode(
            group: "test-project", artifact: "app", requestedVersion: "module",
            children: [TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "lib-a")]
        )
        let moduleB = TestDependencyTreeFactory.makeNode(
            group: "test-project", artifact: "core", requestedVersion: "module",
            children: [TestDependencyTreeFactory.makeNode(group: "com.b", artifact: "lib-b")]
        )
        let tree = DependencyTree(
            projectName: "test-project",
            configuration: .compileClasspath,
            roots: [moduleA, moduleB],
            conflicts: []
        )
        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        #expect(results.isEmpty)
    }

    @Test
    func crossModuleVersionMismatch() {
        let tree = TestDependencyTreeFactory.makeMultiModuleTree(versionMismatch: true)
        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        #expect(results.count == 1)
        #expect(results[0].hasVersionMismatch)
        #expect(results[0].recommendation.contains("mismatch"))
    }

    @Test
    func singleModuleReturnsNoCrossModule() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        #expect(results.isEmpty)
    }

    @Test
    func withinModuleDuplicateDeclaration() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let buildContent = """
        dependencies {
            implementation 'com.google.guava:guava:31.1-jre'
            testImplementation 'com.google.guava:guava:31.1-jre'
        }
        """
        try buildContent.write(to: tempDir.appendingPathComponent("build.gradle"), atomically: true, encoding: .utf8)

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: []
        )
        #expect(results.count == 1)
        #expect(results[0].kind == DuplicateDependencyResult.DuplicateKind.withinModule)
        #expect(results[0].coordinate == "com.google.guava:guava")
    }

    @Test
    func withinModuleNoDuplicates() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let buildContent = """
        dependencies {
            implementation 'com.google.guava:guava:31.1-jre'
            implementation 'org.slf4j:slf4j-api:1.7.36'
        }
        """
        try buildContent.write(to: tempDir.appendingPathComponent("build.gradle"), atomically: true, encoding: .utf8)

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: []
        )
        #expect(results.isEmpty)
    }

    @Test
    func resultsSortedByCoordinate() {
        let moduleA = TestDependencyTreeFactory.makeNode(
            group: "test-project", artifact: "app", requestedVersion: "module",
            children: [
                TestDependencyTreeFactory.makeNode(group: "org.z", artifact: "z-lib"),
                TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "a-lib"),
            ]
        )
        let moduleB = TestDependencyTreeFactory.makeNode(
            group: "test-project", artifact: "core", requestedVersion: "module",
            children: [
                TestDependencyTreeFactory.makeNode(group: "org.z", artifact: "z-lib"),
                TestDependencyTreeFactory.makeNode(group: "com.a", artifact: "a-lib"),
            ]
        )
        let tree = DependencyTree(
            projectName: "test-project",
            configuration: .compileClasspath,
            roots: [moduleA, moduleB],
            conflicts: []
        )
        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        let coordinates = results.map(\.coordinate)
        #expect(coordinates == coordinates.sorted())
    }
}
