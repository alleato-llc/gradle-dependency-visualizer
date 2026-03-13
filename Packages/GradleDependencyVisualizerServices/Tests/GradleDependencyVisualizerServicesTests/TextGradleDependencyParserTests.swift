import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Suite
struct TextGradleDependencyParserTests {
    let parser = TextGradleDependencyParser()

    @Test
    func parsesSimpleDependency() {
        let output = """
        +--- org.springframework:spring-core:5.3.20
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].group == "org.springframework")
        #expect(tree.roots[0].artifact == "spring-core")
        #expect(tree.roots[0].requestedVersion == "5.3.20")
    }

    @Test
    func parsesNestedDependencies() {
        let output = """
        +--- org.springframework:spring-core:5.3.20
        |    +--- com.google.guava:guava:31.1-jre
        |    \\--- org.slf4j:slf4j-api:1.7.36
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].children.count == 2)
        #expect(tree.roots[0].children[0].artifact == "guava")
        #expect(tree.roots[0].children[1].artifact == "slf4j-api")
    }

    @Test
    func parsesConflictMarker() {
        let output = """
        +--- com.fasterxml.jackson.core:jackson-databind:2.13.0 -> 2.14.2
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        let node = tree.roots[0]
        #expect(node.requestedVersion == "2.13.0")
        #expect(node.resolvedVersion == "2.14.2")
        #expect(node.hasConflict)
        #expect(tree.conflicts.count == 1)
    }

    @Test
    func parsesOmittedMarker() {
        let output = """
        +--- org.slf4j:slf4j-api:1.7.36 (*)
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].isOmitted)
    }

    @Test
    func parsesConstraintMarker() {
        let output = """
        +--- org.slf4j:slf4j-api:1.7.36 (c)
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].isConstraint)
    }

    @Test
    func parsesMultipleRoots() {
        let output = """
        +--- org.springframework:spring-core:5.3.20
        +--- com.google.guava:guava:31.1-jre
        \\--- org.slf4j:slf4j-api:1.7.36
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 3)
    }

    @Test
    func parsesDeeplyNestedTree() {
        let output = """
        +--- com.example:a:1.0
        |    +--- com.example:b:2.0
        |    |    \\--- com.example:c:3.0
        |    \\--- com.example:d:4.0
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        let a = tree.roots[0]
        #expect(a.children.count == 2)
        #expect(a.children[0].artifact == "b")
        #expect(a.children[0].children.count == 1)
        #expect(a.children[0].children[0].artifact == "c")
        #expect(a.children[1].artifact == "d")
    }

    @Test
    func parsesConflictWithParentTracking() {
        let output = """
        +--- org.springframework:spring-web:5.3.20
        |    +--- com.fasterxml.jackson.core:jackson-databind:2.13.0 -> 2.14.2
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.conflicts.count == 1)
        #expect(tree.conflicts[0].requestedBy == "org.springframework:spring-web")
    }

    @Test
    func ignoresNonDependencyLines() {
        let output = """

        ------------------------------------------------------------
        Project ':app'
        ------------------------------------------------------------

        compileClasspath - Compile classpath for source set 'main'.
        +--- org.springframework:spring-core:5.3.20

        (*) - Repeated dependencies omitted
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].artifact == "spring-core")
    }

    @Test
    func emptyOutputProducesEmptyTree() {
        let tree = parser.parse(output: "", projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.isEmpty)
        #expect(tree.conflicts.isEmpty)
    }
}
