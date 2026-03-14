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
    func parsesBomManagedDependencyWithoutRequestedVersion() {
        let output = """
        +--- org.springframework.boot:spring-boot-starter-web -> 3.5.11
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        let node = tree.roots[0]
        #expect(node.group == "org.springframework.boot")
        #expect(node.artifact == "spring-boot-starter-web")
        #expect(node.requestedVersion == "3.5.11")
        #expect(node.resolvedVersion == nil)
        #expect(node.hasConflict == false)
    }

    @Test
    func parsesBomManagedDependencyWithChildren() {
        let output = """
        +--- org.springframework.boot:spring-boot-starter-web -> 3.5.11
        |    +--- org.springframework.boot:spring-boot-starter:3.5.11
        |    \\--- org.springframework:spring-webmvc:6.2.16
        """

        let tree = parser.parse(output: output, projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].artifact == "spring-boot-starter-web")
        #expect(tree.roots[0].children.count == 2)
        #expect(tree.roots[0].children[0].artifact == "spring-boot-starter")
        #expect(tree.roots[0].children[1].artifact == "spring-webmvc")
    }

    @Test
    func parsesSpringBootMultiRootBomManagedProject() {
        // Simulates a Spring Boot project with BOM-managed dependencies,
        // constraints, conflicts, and deeply nested subtrees
        let output = """
        > Task :dependencies

        ------------------------------------------------------------
        Root project 'spring-boot-testing-reference'
        ------------------------------------------------------------

        compileClasspath - Compile classpath for source set 'main'.
        +--- org.springframework.boot:spring-boot-starter-web -> 3.5.11
        |    +--- org.springframework.boot:spring-boot-starter:3.5.11
        |    |    +--- org.springframework.boot:spring-boot:3.5.11
        |    |    |    +--- org.springframework:spring-core:6.2.16
        |    |    |    |    \\--- org.springframework:spring-jcl:6.2.16
        |    |    |    \\--- org.springframework:spring-context:6.2.16
        |    |    |         +--- org.springframework:spring-aop:6.2.16
        |    |    |         |    +--- org.springframework:spring-beans:6.2.16
        |    |    |         |    |    \\--- org.springframework:spring-core:6.2.16 (*)
        |    |    |         |    \\--- org.springframework:spring-core:6.2.16 (*)
        |    |    |         +--- org.springframework:spring-beans:6.2.16 (*)
        |    |    |         +--- org.springframework:spring-core:6.2.16 (*)
        |    |    |         \\--- org.springframework:spring-expression:6.2.16
        |    |    |              \\--- org.springframework:spring-core:6.2.16 (*)
        |    |    +--- org.springframework.boot:spring-boot-autoconfigure:3.5.11
        |    |    |    \\--- org.springframework.boot:spring-boot:3.5.11 (*)
        |    |    \\--- org.yaml:snakeyaml:2.4
        |    +--- org.springframework.boot:spring-boot-starter-json:3.5.11
        |    |    +--- com.fasterxml.jackson.core:jackson-databind:2.19.4
        |    |    |    +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4
        |    |    |    |    \\--- com.fasterxml.jackson:jackson-bom:2.19.4
        |    |    |    |         +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4 (c)
        |    |    |    |         +--- com.fasterxml.jackson.core:jackson-core:2.19.4 (c)
        |    |    |    |         \\--- com.fasterxml.jackson.core:jackson-databind:2.19.4 (c)
        |    |    |    \\--- com.fasterxml.jackson.core:jackson-core:2.19.4
        |    |    |         \\--- com.fasterxml.jackson:jackson-bom:2.19.4 (*)
        |    |    \\--- com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.19.4
        |    |         +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4 (*)
        |    |         +--- com.fasterxml.jackson.core:jackson-core:2.19.4 (*)
        |    |         +--- com.fasterxml.jackson.core:jackson-databind:2.19.4 (*)
        |    |         \\--- com.fasterxml.jackson:jackson-bom:2.19.4 (*)
        |    \\--- org.springframework:spring-webmvc:6.2.16
        |         +--- org.springframework:spring-aop:6.2.16 (*)
        |         +--- org.springframework:spring-beans:6.2.16 (*)
        |         \\--- org.springframework:spring-web:6.2.16 (*)
        +--- org.springframework.boot:spring-boot-starter-data-jpa -> 3.5.11
        |    +--- org.springframework.boot:spring-boot-starter:3.5.11 (*)
        |    +--- org.hibernate.orm:hibernate-core:6.6.42.Final
        |    |    +--- jakarta.persistence:jakarta.persistence-api:3.1.0
        |    |    \\--- jakarta.transaction:jakarta.transaction-api:2.0.1
        |    \\--- org.springframework.data:spring-data-jpa:3.5.9
        |         +--- org.springframework:spring-core:6.2.15 -> 6.2.16 (*)
        |         +--- org.springframework:spring-beans:6.2.15 -> 6.2.16 (*)
        |         \\--- org.antlr:antlr4-runtime:4.13.0
        +--- software.amazon.awssdk:bom:2.42.11
        |    +--- software.amazon.awssdk:s3:2.42.11 (c)
        |    \\--- software.amazon.awssdk:sns:2.42.11 (c)
        \\--- org.testng:testng:7.0.0
             \\--- com.beust:jcommander:1.72
        """

        let tree = parser.parse(
            output: output,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        // Verify all 4 root dependencies are parsed
        #expect(tree.roots.count == 4)

        // First root: BOM-managed spring-boot-starter-web
        let web = tree.roots[0]
        #expect(web.group == "org.springframework.boot")
        #expect(web.artifact == "spring-boot-starter-web")
        #expect(web.requestedVersion == "3.5.11")
        #expect(web.resolvedVersion == nil)
        #expect(web.children.count == 3) // starter, starter-json, spring-webmvc

        // Second root: BOM-managed spring-boot-starter-data-jpa
        let jpa = tree.roots[1]
        #expect(jpa.artifact == "spring-boot-starter-data-jpa")
        #expect(jpa.requestedVersion == "3.5.11")
        #expect(jpa.children.count == 3) // starter (*), hibernate, spring-data-jpa

        // Third root: BOM with constraints
        let bom = tree.roots[2]
        #expect(bom.group == "software.amazon.awssdk")
        #expect(bom.artifact == "bom")
        #expect(bom.requestedVersion == "2.42.11")
        #expect(bom.children.count == 2)
        #expect(bom.children[0].isConstraint)
        #expect(bom.children[1].isConstraint)

        // Fourth root: regular dependency
        let testng = tree.roots[3]
        #expect(testng.artifact == "testng")
        #expect(testng.children.count == 1)
        #expect(testng.children[0].artifact == "jcommander")

        // Verify conflicts from spring-data-jpa resolving spring versions
        let springConflicts = tree.conflicts.filter { $0.coordinate.contains("spring-") }
        #expect(!springConflicts.isEmpty)

        // Verify constraint nodes from jackson-bom
        let allNodes = collectAllNodes(from: tree)
        let constraintNodes = allNodes.filter(\.isConstraint)
        #expect(constraintNodes.count >= 3) // jackson-annotations (c), jackson-core (c), jackson-databind (c)

        // Verify omitted nodes
        let omittedNodes = allNodes.filter(\.isOmitted)
        #expect(!omittedNodes.isEmpty)

        // Verify total node count covers all parsed lines
        #expect(tree.totalNodeCount > 40)
    }

    private func collectAllNodes(from tree: DependencyTree) -> [DependencyNode] {
        var nodes: [DependencyNode] = []
        func visit(_ node: DependencyNode) {
            nodes.append(node)
            for child in node.children { visit(child) }
        }
        tree.roots.forEach { visit($0) }
        return nodes
    }

    @Test
    func emptyOutputProducesEmptyTree() {
        let tree = parser.parse(output: "", projectName: "test", configuration: .compileClasspath)
        #expect(tree.roots.isEmpty)
        #expect(tree.conflicts.isEmpty)
    }
}
