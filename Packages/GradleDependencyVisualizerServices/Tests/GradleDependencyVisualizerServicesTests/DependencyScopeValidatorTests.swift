import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct DependencyScopeValidatorTests {
    @Test
    func productionConfigWithTestLibrariesReturnsResults() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries(configuration: .compileClasspath)
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(!results.isEmpty)
        #expect(results.count == 3)
    }

    @Test
    func testConfigReturnsEmpty() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries(configuration: .testCompileClasspath)
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(results.isEmpty)
    }

    @Test
    func noTestLibrariesReturnsEmpty() {
        let tree = TestDependencyTreeFactory.makeSimpleTree()
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(results.isEmpty)
    }

    @Test
    func wildcardMatchingWorks() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "org.junit.jupiter",
            artifact: "junit-jupiter-api",
            requestedVersion: "5.9.3"
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(results.count == 1)
        #expect(results.first?.matchedLibrary == "JUnit 5")
    }

    @Test
    func exactMatchingWorks() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "junit",
            artifact: "junit",
            requestedVersion: "4.13.2"
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .implementation,
            roots: [node],
            conflicts: []
        )
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(results.count == 1)
        #expect(results.first?.matchedLibrary == "JUnit 4")
    }

    @Test
    func deduplicatesSameCoordinate() {
        let junit1 = TestDependencyTreeFactory.makeNode(
            group: "junit", artifact: "junit", requestedVersion: "4.13.2"
        )
        let junit2 = TestDependencyTreeFactory.makeNode(
            group: "junit", artifact: "junit", requestedVersion: "4.13.2"
        )
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.example", artifact: "app", requestedVersion: "1.0",
            children: [junit1, junit2]
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .runtimeClasspath,
            roots: [root],
            conflicts: []
        )
        let results = DependencyScopeValidator.validate(tree: tree)
        let junitResults = results.filter { $0.coordinate == "junit:junit" }
        #expect(junitResults.count == 1)
    }

    @Test
    func subGroupMatchingWorks() {
        let node = TestDependencyTreeFactory.makeNode(
            group: "org.jboss.arquillian.core",
            artifact: "arquillian-core-api",
            requestedVersion: "1.7.0"
        )
        let tree = DependencyTree(
            projectName: "test",
            configuration: .compileClasspath,
            roots: [node],
            conflicts: []
        )
        let results = DependencyScopeValidator.validate(tree: tree)
        #expect(results.count == 1)
        #expect(results.first?.matchedLibrary == "Arquillian")
    }

    @Test
    func resultsSortedByCoordinate() {
        let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries()
        let results = DependencyScopeValidator.validate(tree: tree)
        let coordinates = results.map(\.coordinate)
        #expect(coordinates == coordinates.sorted())
    }

    @Test
    func allProductionConfigurationsAreChecked() {
        let productionConfigs: [GradleConfiguration] = [
            .compileClasspath, .runtimeClasspath, .implementation,
            .runtimeOnly, .compileOnly, .api,
        ]
        for config in productionConfigs {
            let tree = TestDependencyTreeFactory.makeTreeWithTestLibraries(configuration: config)
            let results = DependencyScopeValidator.validate(tree: tree)
            #expect(!results.isEmpty, "Expected results for \(config.rawValue)")
        }
    }
}
