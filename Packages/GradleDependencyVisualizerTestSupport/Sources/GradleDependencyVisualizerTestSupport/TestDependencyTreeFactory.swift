import GradleDependencyVisualizerCore

public enum TestDependencyTreeFactory {
    public static func makeSimpleTree(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .compileClasspath
    ) -> DependencyTree {
        let leafA = DependencyNode(group: "com.google.guava", artifact: "guava", requestedVersion: "31.1-jre")
        let leafB = DependencyNode(group: "org.slf4j", artifact: "slf4j-api", requestedVersion: "1.7.36")
        let root = DependencyNode(
            group: "org.springframework",
            artifact: "spring-core",
            requestedVersion: "5.3.20",
            children: [leafA, leafB]
        )
        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [root],
            conflicts: []
        )
    }

    public static func makeTreeWithConflicts(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .runtimeClasspath
    ) -> DependencyTree {
        let conflictNode = DependencyNode(
            group: "com.fasterxml.jackson.core",
            artifact: "jackson-databind",
            requestedVersion: "2.13.0",
            resolvedVersion: "2.14.2"
        )
        let childA = DependencyNode(
            group: "org.springframework",
            artifact: "spring-web",
            requestedVersion: "5.3.20",
            children: [conflictNode]
        )
        let directJackson = DependencyNode(
            group: "com.fasterxml.jackson.core",
            artifact: "jackson-databind",
            requestedVersion: "2.14.2"
        )
        let conflict = DependencyConflict(
            coordinate: "com.fasterxml.jackson.core:jackson-databind",
            requestedVersion: "2.13.0",
            resolvedVersion: "2.14.2",
            requestedBy: "org.springframework:spring-web"
        )
        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [childA, directJackson],
            conflicts: [conflict]
        )
    }

    public static func makeDeepTree(depth: Int = 5) -> DependencyTree {
        func buildChain(currentDepth: Int) -> DependencyNode {
            let node = DependencyNode(
                group: "com.example",
                artifact: "lib-\(currentDepth)",
                requestedVersion: "1.0.\(currentDepth)",
                children: currentDepth < depth ? [buildChain(currentDepth: currentDepth + 1)] : []
            )
            return node
        }
        let root = buildChain(currentDepth: 0)
        return DependencyTree(
            projectName: "deep-project",
            configuration: .compileClasspath,
            roots: [root],
            conflicts: []
        )
    }

    public static func makeTreeWithTestLibraries(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .compileClasspath
    ) -> DependencyTree {
        let junit = DependencyNode(group: "junit", artifact: "junit", requestedVersion: "4.13.2")
        let mockito = DependencyNode(group: "org.mockito", artifact: "mockito-core", requestedVersion: "5.3.1")
        let jupiterApi = DependencyNode(group: "org.junit.jupiter", artifact: "junit-jupiter-api", requestedVersion: "5.9.3")
        let guava = DependencyNode(group: "com.google.guava", artifact: "guava", requestedVersion: "31.1-jre")
        let root = DependencyNode(
            group: "com.example",
            artifact: "my-app",
            requestedVersion: "1.0.0",
            children: [junit, mockito, jupiterApi, guava]
        )
        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [root],
            conflicts: []
        )
    }

    public static func makeModule(
        name: String = "app",
        path: String? = nil
    ) -> GradleModule {
        GradleModule(name: name, path: path ?? ":\(name)")
    }

    public static func makeNode(
        group: String = "com.example",
        artifact: String = "lib",
        requestedVersion: String = "1.0.0",
        resolvedVersion: String? = nil,
        isOmitted: Bool = false,
        isConstraint: Bool = false,
        children: [DependencyNode] = []
    ) -> DependencyNode {
        DependencyNode(
            group: group,
            artifact: artifact,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            isOmitted: isOmitted,
            isConstraint: isConstraint,
            children: children
        )
    }
}
