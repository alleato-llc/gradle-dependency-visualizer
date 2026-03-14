import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

/// Integration tests that verify the full pipeline from real Gradle output
/// through parsing to tree layout. Uses actual `gradle dependencies` output
/// from the spring-boot-testing-reference project.
@Suite
struct ParseToLayoutIntegrationTests {
    let parser = TextGradleDependencyParser()

    // MARK: - Fixtures

    /// Checkstyle configuration from spring-boot-testing-reference. Single root
    /// with deep nesting, version conflicts (->), and omitted nodes (*).
    static let checkstyleConfiguration = """
    \\--- com.puppycrawl.tools:checkstyle:10.21.1
         +--- info.picocli:picocli:4.7.6
         +--- org.antlr:antlr4-runtime:4.13.2
         +--- commons-beanutils:commons-beanutils:1.9.4 -> 1.11.0
         |    \\--- commons-collections:commons-collections:3.2.2
         +--- com.google.guava:guava:33.4.0-jre
         |    +--- com.google.guava:failureaccess:1.0.2
         |    +--- com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava
         |    +--- com.google.code.findbugs:jsr305:3.0.2
         |    +--- com.google.errorprone:error_prone_annotations:2.36.0
         |    \\--- com.google.j2objc:j2objc-annotations:3.0.0
         +--- org.reflections:reflections:0.10.2
         |    +--- org.javassist:javassist:3.28.0-GA
         |    \\--- com.google.code.findbugs:jsr305:3.0.2
         +--- net.sf.saxon:Saxon-HE:12.5
         |    \\--- org.xmlresolver:xmlresolver:5.2.2
         |         +--- org.apache.httpcomponents.client5:httpclient5:5.1.3 -> 5.5.2
         |         |    +--- org.apache.httpcomponents.core5:httpcore5:5.3.6
         |         |    \\--- org.apache.httpcomponents.core5:httpcore5-h2:5.3.6
         |         |         \\--- org.apache.httpcomponents.core5:httpcore5:5.3.6
         |         \\--- org.apache.httpcomponents.core5:httpcore5:5.1.3 -> 5.3.6
         +--- org.checkerframework:checker-qual:3.48.3
         +--- org.apache.maven.doxia:doxia-core:1.12.0
         |    +--- org.apache.maven.doxia:doxia-sink-api:1.12.0
         |    |    \\--- org.apache.maven.doxia:doxia-logging-api:1.12.0
         |    |         \\--- org.codehaus.plexus:plexus-container-default:2.1.0
         |    |              +--- org.codehaus.plexus:plexus-utils:3.1.1 -> 3.3.0
         |    |              +--- org.codehaus.plexus:plexus-classworlds:2.6.0
         |    |              \\--- org.apache.xbean:xbean-reflect:3.7
         |    +--- org.apache.maven.doxia:doxia-logging-api:1.12.0 (*)
         |    +--- org.codehaus.plexus:plexus-utils:3.3.0
         |    +--- org.codehaus.plexus:plexus-container-default:2.1.0 (*)
         |    +--- org.codehaus.plexus:plexus-component-annotations:2.1.0
         |    +--- org.apache.commons:commons-lang3:3.8.1 -> 3.17.0
         |    +--- org.apache.commons:commons-text:1.3
         |    |    \\--- org.apache.commons:commons-lang3:3.7 -> 3.17.0
         |    +--- org.apache.httpcomponents:httpclient:4.5.13
         |    |    \\--- org.apache.httpcomponents:httpcore:4.4.13 -> 4.4.16
         |    \\--- org.apache.httpcomponents:httpcore:4.4.14 -> 4.4.16
         \\--- org.apache.maven.doxia:doxia-module-xdoc:1.12.0
              +--- org.codehaus.plexus:plexus-utils:3.3.0
              +--- org.apache.maven.doxia:doxia-core:1.12.0 (*)
              +--- org.apache.maven.doxia:doxia-sink-api:1.12.0 (*)
              \\--- org.codehaus.plexus:plexus-component-annotations:2.1.0
    """

    /// compileClasspath subset: BOM-managed roots (group:artifact -> version),
    /// Jackson BOM constraints (c), and slf4j version conflict.
    static let compileClasspathSubset = """
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
    |    |    |         +--- org.springframework:spring-expression:6.2.16
    |    |    |         |    \\--- org.springframework:spring-core:6.2.16 (*)
    |    |    |         \\--- io.micrometer:micrometer-observation:1.15.9
    |    |    |              \\--- io.micrometer:micrometer-commons:1.15.9
    |    |    +--- org.springframework.boot:spring-boot-autoconfigure:3.5.11
    |    |    |    \\--- org.springframework.boot:spring-boot:3.5.11 (*)
    |    |    +--- org.springframework.boot:spring-boot-starter-logging:3.5.11
    |    |    |    +--- ch.qos.logback:logback-classic:1.5.32
    |    |    |    |    +--- ch.qos.logback:logback-core:1.5.32
    |    |    |    |    \\--- org.slf4j:slf4j-api:2.0.17
    |    |    |    +--- org.apache.logging.log4j:log4j-to-slf4j:2.24.3
    |    |    |    |    +--- org.apache.logging.log4j:log4j-api:2.24.3
    |    |    |    |    \\--- org.slf4j:slf4j-api:2.0.16 -> 2.0.17
    |    |    |    \\--- org.slf4j:jul-to-slf4j:2.0.17
    |    |    |         \\--- org.slf4j:slf4j-api:2.0.17
    |    |    +--- jakarta.annotation:jakarta.annotation-api:2.1.1
    |    |    +--- org.springframework:spring-core:6.2.16 (*)
    |    |    \\--- org.yaml:snakeyaml:2.4
    |    +--- org.springframework.boot:spring-boot-starter-json:3.5.11
    |    |    +--- com.fasterxml.jackson.core:jackson-databind:2.19.4
    |    |    |    +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4
    |    |    |    |    \\--- com.fasterxml.jackson:jackson-bom:2.19.4
    |    |    |    |         +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4 (c)
    |    |    |    |         +--- com.fasterxml.jackson.core:jackson-core:2.19.4 (c)
    |    |    |    |         \\--- com.fasterxml.jackson.core:jackson-databind:2.19.4 (c)
    |    |    |    +--- com.fasterxml.jackson.core:jackson-core:2.19.4
    |    |    |    |    \\--- com.fasterxml.jackson:jackson-bom:2.19.4 (*)
    |    |    |    \\--- com.fasterxml.jackson:jackson-bom:2.19.4 (*)
    |    |    \\--- com.fasterxml.jackson.datatype:jackson-datatype-jdk8:2.19.4
    |    |         +--- com.fasterxml.jackson.core:jackson-core:2.19.4 (*)
    |    |         +--- com.fasterxml.jackson.core:jackson-databind:2.19.4 (*)
    |    |         \\--- com.fasterxml.jackson:jackson-bom:2.19.4 (*)
    |    \\--- org.springframework:spring-webmvc:6.2.16
    |         +--- org.springframework:spring-aop:6.2.16 (*)
    |         +--- org.springframework:spring-beans:6.2.16 (*)
    |         +--- org.springframework:spring-context:6.2.16 (*)
    |         +--- org.springframework:spring-core:6.2.16 (*)
    |         +--- org.springframework:spring-expression:6.2.16 (*)
    |         \\--- org.springframework:spring-web:6.2.16 (*)
    +--- org.springframework.boot:spring-boot-starter-data-jpa -> 3.5.11
    |    +--- org.springframework.boot:spring-boot-starter:3.5.11 (*)
    |    +--- org.springframework.boot:spring-boot-starter-jdbc:3.5.11
    |    |    +--- org.springframework.boot:spring-boot-starter:3.5.11 (*)
    |    |    +--- com.zaxxer:HikariCP:6.3.3
    |    |    |    \\--- org.slf4j:slf4j-api:2.0.17
    |    |    \\--- org.springframework:spring-jdbc:6.2.16
    |    |         +--- org.springframework:spring-beans:6.2.16 (*)
    |    |         +--- org.springframework:spring-core:6.2.16 (*)
    |    |         \\--- org.springframework:spring-tx:6.2.16
    |    |              +--- org.springframework:spring-beans:6.2.16 (*)
    |    |              \\--- org.springframework:spring-core:6.2.16 (*)
    |    +--- org.hibernate.orm:hibernate-core:6.6.42.Final
    |    |    +--- jakarta.persistence:jakarta.persistence-api:3.1.0
    |    |    \\--- jakarta.transaction:jakarta.transaction-api:2.0.1
    |    +--- org.springframework.data:spring-data-jpa:3.5.9
    |    |    +--- org.springframework.data:spring-data-commons:3.5.9
    |    |    |    +--- org.springframework:spring-core:6.2.15 -> 6.2.16 (*)
    |    |    |    +--- org.springframework:spring-beans:6.2.15 -> 6.2.16 (*)
    |    |    |    \\--- org.slf4j:slf4j-api:2.0.17
    |    |    +--- org.springframework:spring-orm:6.2.15 -> 6.2.16
    |    |    |    +--- org.springframework:spring-beans:6.2.16 (*)
    |    |    |    +--- org.springframework:spring-core:6.2.16 (*)
    |    |    |    +--- org.springframework:spring-jdbc:6.2.16 (*)
    |    |    |    \\--- org.springframework:spring-tx:6.2.16 (*)
    |    |    +--- org.springframework:spring-context:6.2.15 -> 6.2.16 (*)
    |    |    +--- org.springframework:spring-aop:6.2.15 -> 6.2.16 (*)
    |    |    +--- org.springframework:spring-tx:6.2.15 -> 6.2.16 (*)
    |    |    +--- org.springframework:spring-beans:6.2.15 -> 6.2.16 (*)
    |    |    +--- org.springframework:spring-core:6.2.15 -> 6.2.16 (*)
    |    |    +--- org.antlr:antlr4-runtime:4.13.0
    |    |    +--- jakarta.annotation:jakarta.annotation-api:2.0.0 -> 2.1.1
    |    |    \\--- org.slf4j:slf4j-api:2.0.17
    |    \\--- org.springframework:spring-aspects:6.2.16
    |         \\--- org.aspectj:aspectjweaver:1.9.22.1 -> 1.9.25.1
    +--- org.springframework.boot:spring-boot-starter-validation -> 3.5.11
    |    +--- org.springframework.boot:spring-boot-starter:3.5.11 (*)
    |    +--- org.apache.tomcat.embed:tomcat-embed-el:10.1.52
    |    \\--- org.hibernate.validator:hibernate-validator:8.0.3.Final
    |         +--- jakarta.validation:jakarta.validation-api:3.0.2
    |         +--- org.jboss.logging:jboss-logging:3.4.3.Final -> 3.6.2.Final
    |         \\--- com.fasterxml:classmate:1.5.1 -> 1.7.3
    """

    // MARK: - Parsing: Checkstyle

    @Test
    func parsesCheckstyleSingleRoot() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        #expect(tree.roots.count == 1)
        #expect(tree.roots[0].group == "com.puppycrawl.tools")
        #expect(tree.roots[0].artifact == "checkstyle")
        #expect(tree.roots[0].requestedVersion == "10.21.1")
    }

    @Test
    func parsesCheckstyleDirectDependencies() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let checkstyle = tree.roots[0]
        let childArtifacts = checkstyle.children.map(\.artifact)

        #expect(childArtifacts.contains("picocli"))
        #expect(childArtifacts.contains("antlr4-runtime"))
        #expect(childArtifacts.contains("commons-beanutils"))
        #expect(childArtifacts.contains("guava"))
        #expect(childArtifacts.contains("reflections"))
        #expect(childArtifacts.contains("Saxon-HE"))
        #expect(childArtifacts.contains("checker-qual"))
        #expect(childArtifacts.contains("doxia-core"))
        #expect(childArtifacts.contains("doxia-module-xdoc"))
    }

    @Test
    func parsesCheckstyleVersionConflicts() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        // commons-beanutils: 1.9.4 -> 1.11.0
        let beanutilsConflicts = tree.conflicts.filter {
            $0.coordinate == "commons-beanutils:commons-beanutils"
        }
        #expect(beanutilsConflicts.count == 1)
        #expect(beanutilsConflicts[0].requestedVersion == "1.9.4")
        #expect(beanutilsConflicts[0].resolvedVersion == "1.11.0")
        // requestedBy tracks the immediate parent on the parser stack
        #expect(!beanutilsConflicts[0].requestedBy.isEmpty)

        // httpclient5: 5.1.3 -> 5.5.2
        let httpclientConflicts = tree.conflicts.filter {
            $0.coordinate == "org.apache.httpcomponents.client5:httpclient5"
        }
        #expect(httpclientConflicts.count == 1)
        #expect(httpclientConflicts[0].requestedVersion == "5.1.3")
        #expect(httpclientConflicts[0].resolvedVersion == "5.5.2")

        // plexus-utils: 3.1.1 -> 3.3.0
        let plexusConflicts = tree.conflicts.filter {
            $0.coordinate == "org.codehaus.plexus:plexus-utils"
        }
        #expect(!plexusConflicts.isEmpty)
        #expect(plexusConflicts.contains { $0.requestedVersion == "3.1.1" && $0.resolvedVersion == "3.3.0" })
    }

    @Test
    func parsesCheckstyleDeepNesting() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        // checkstyle > doxia-core > doxia-sink-api > doxia-logging-api > plexus-container-default > plexus-utils
        let checkstyle = tree.roots[0]
        let doxiaCore = checkstyle.children.first { $0.artifact == "doxia-core" }
        let doxiaSinkApi = doxiaCore?.children.first { $0.artifact == "doxia-sink-api" }
        let doxiaLoggingApi = doxiaSinkApi?.children.first { $0.artifact == "doxia-logging-api" }
        let plexusContainer = doxiaLoggingApi?.children.first { $0.artifact == "plexus-container-default" }

        #expect(plexusContainer != nil)
        #expect(plexusContainer?.children.count == 3)

        let plexusUtils = plexusContainer?.children.first { $0.artifact == "plexus-utils" }
        #expect(plexusUtils != nil)
        #expect(plexusUtils?.hasConflict == true)
        #expect(plexusUtils?.requestedVersion == "3.1.1")
        #expect(plexusUtils?.resolvedVersion == "3.3.0")
    }

    @Test
    func parsesCheckstyleOmittedNodes() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        func collectOmitted(_ nodes: [DependencyNode]) -> [DependencyNode] {
            nodes.flatMap { node in
                (node.isOmitted ? [node] : []) + collectOmitted(node.children)
            }
        }

        let omitted = collectOmitted(tree.roots)
        // doxia-logging-api (*), plexus-container-default (*), doxia-core (*), doxia-sink-api (*)
        #expect(omitted.count >= 4)
        #expect(omitted.contains { $0.artifact == "doxia-logging-api" })
        #expect(omitted.contains { $0.artifact == "doxia-core" })
    }

    @Test
    func checkstyleTreeHasExpectedComplexity() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        #expect(tree.totalNodeCount > 35)
        #expect(tree.maxDepth >= 6)
    }

    // MARK: - Parsing: compileClasspath subset

    @Test
    func parsesCompileClasspathBomManagedRoots() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        #expect(tree.roots.count == 3)
        #expect(tree.roots[0].artifact == "spring-boot-starter-web")
        #expect(tree.roots[0].requestedVersion == "3.5.11")
        #expect(tree.roots[0].hasConflict == false)
        #expect(tree.roots[1].artifact == "spring-boot-starter-data-jpa")
        #expect(tree.roots[2].artifact == "spring-boot-starter-validation")
    }

    @Test
    func parsesSlf4jVersionConflict() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        let slf4jConflicts = tree.conflicts.filter { $0.coordinate == "org.slf4j:slf4j-api" }
        #expect(!slf4jConflicts.isEmpty)
        #expect(slf4jConflicts.contains { $0.requestedVersion == "2.0.16" && $0.resolvedVersion == "2.0.17" })
    }

    @Test
    func parsesConstraintNodesFromJacksonBom() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        func findConstraints(_ nodes: [DependencyNode]) -> [DependencyNode] {
            nodes.flatMap { node in
                (node.isConstraint ? [node] : []) + findConstraints(node.children)
            }
        }

        let constraints = findConstraints(tree.roots)
        #expect(constraints.count == 3)

        let constraintArtifacts = Set(constraints.map(\.artifact))
        #expect(constraintArtifacts.contains("jackson-annotations"))
        #expect(constraintArtifacts.contains("jackson-core"))
        #expect(constraintArtifacts.contains("jackson-databind"))
    }

    @Test
    func parsesSpringDataVersionConflicts() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        // spring-data-jpa subtree has multiple 6.2.15 -> 6.2.16 conflicts
        let springConflicts = tree.conflicts.filter {
            $0.coordinate.starts(with: "org.springframework:") && $0.requestedVersion == "6.2.15"
        }
        #expect(springConflicts.count >= 5)
        for conflict in springConflicts {
            #expect(conflict.resolvedVersion == "6.2.16")
        }
    }

    @Test
    func parsesDeepSpringContextChain() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )

        // starter-web > starter > spring-boot > spring-context > spring-aop > spring-beans > spring-core (*)
        let starterWeb = tree.roots[0]
        let starter = starterWeb.children.first { $0.artifact == "spring-boot-starter" }
        let springBoot = starter?.children.first { $0.artifact == "spring-boot" }
        let springContext = springBoot?.children.first { $0.artifact == "spring-context" }
        let springAop = springContext?.children.first { $0.artifact == "spring-aop" }
        let springBeans = springAop?.children.first { $0.artifact == "spring-beans" }
        let springCore = springBeans?.children.first { $0.artifact == "spring-core" }

        #expect(springCore != nil)
        #expect(springCore?.isOmitted == true)
        #expect(springCore?.requestedVersion == "6.2.16")
    }

    // MARK: - Layout: Checkstyle

    @Test
    func layoutProducesPositionForEveryVisibleNode() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        // Omitted/constraint leaf nodes are excluded from layout to reduce canvas width
        #expect(positions.count <= tree.totalNodeCount)
        #expect(positions.count > 0)

        // Every position should map to a real node
        let allNodeIds = collectAllNodeIds(from: tree)
        for pos in positions {
            #expect(allNodeIds.contains(pos.nodeId))
        }
    }

    @Test
    func layoutPositionsAreNonNegative() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        for pos in positions {
            #expect(pos.x >= 0)
            #expect(pos.y >= 0)
        }
    }

    @Test
    func layoutHasMultipleDepthLevels() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        let uniqueYValues = Set(positions.map(\.y))
        #expect(uniqueYValues.count >= 6)
    }

    @Test
    func layoutChildrenAreDeeperThanParents() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)
        let posMap = Dictionary(uniqueKeysWithValues: positions.map { ($0.nodeId, $0) })

        func verifyChildrenDeeper(_ nodes: [DependencyNode]) {
            for node in nodes {
                guard let parentPos = posMap[node.id] else { continue }
                for child in node.children {
                    guard let childPos = posMap[child.id] else { continue }
                    #expect(childPos.y > parentPos.y)
                }
                verifyChildrenDeeper(node.children)
            }
        }

        verifyChildrenDeeper(tree.roots)
    }

    @Test
    func layoutNodeIdsAreUnique() {
        let tree = parser.parse(
            output: Self.checkstyleConfiguration,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        let ids = positions.map(\.nodeId)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Layout: compileClasspath subset

    @Test
    func layoutCompileClasspathRootsShareSameDepth() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        let rootIds = Set(tree.roots.map(\.id))
        let rootPositions = positions.filter { rootIds.contains($0.nodeId) }

        #expect(rootPositions.count == 3)
        let rootYValues = Set(rootPositions.map(\.y))
        #expect(rootYValues.count == 1, "All roots should be at the same Y depth")
    }

    @Test
    func layoutCompileClasspathPositionCount() {
        let tree = parser.parse(
            output: Self.compileClasspathSubset,
            projectName: "spring-boot-testing-reference",
            configuration: .compileClasspath
        )
        let positions = TreeLayoutCalculator.layout(tree: tree)

        // Omitted/constraint leaf nodes are excluded from layout
        #expect(positions.count <= tree.totalNodeCount)
        #expect(positions.count > 40)
    }

    private func collectAllNodeIds(from tree: DependencyTree) -> Set<String> {
        var ids = Set<String>()
        func visit(_ node: DependencyNode) {
            ids.insert(node.id)
            for child in node.children { visit(child) }
        }
        tree.roots.forEach { visit($0) }
        return ids
    }
}
