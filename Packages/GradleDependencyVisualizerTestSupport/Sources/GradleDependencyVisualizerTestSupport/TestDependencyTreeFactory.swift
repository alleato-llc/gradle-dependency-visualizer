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

    public static func makeMultiModuleTree(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .compileClasspath,
        sharedDependency: (group: String, artifact: String, version: String) = ("com.google.guava", "guava", "31.1-jre"),
        versionMismatch: Bool = false
    ) -> DependencyTree {
        let sharedA = DependencyNode(
            group: sharedDependency.group,
            artifact: sharedDependency.artifact,
            requestedVersion: sharedDependency.version
        )
        let uniqueA = DependencyNode(
            group: "com.example",
            artifact: "lib-a-only",
            requestedVersion: "1.0.0"
        )
        let moduleA = DependencyNode(
            group: projectName,
            artifact: "app",
            requestedVersion: "module",
            children: [sharedA, uniqueA]
        )

        let sharedBVersion = versionMismatch ? "30.0-jre" : sharedDependency.version
        let sharedB = DependencyNode(
            group: sharedDependency.group,
            artifact: sharedDependency.artifact,
            requestedVersion: sharedBVersion
        )
        let uniqueB = DependencyNode(
            group: "com.example",
            artifact: "lib-b-only",
            requestedVersion: "2.0.0"
        )
        let moduleB = DependencyNode(
            group: projectName,
            artifact: "core",
            requestedVersion: "module",
            children: [sharedB, uniqueB]
        )

        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [moduleA, moduleB],
            conflicts: []
        )
    }

    public static func makeTreeWithBOMConstraints(
        projectName: String = "test-project",
        configuration: GradleConfiguration = .compileClasspath,
        conflictCoordinate: String = "org.slf4j:slf4j-api",
        requestedVersion: String = "1.7.36",
        resolvedVersion: String = "2.0.17"
    ) -> DependencyTree {
        let parts = conflictCoordinate.split(separator: ":")
        let group = String(parts[0])
        let artifact = String(parts[1])

        let constraintNode = DependencyNode(
            group: group,
            artifact: artifact,
            requestedVersion: resolvedVersion,
            resolvedVersion: resolvedVersion,
            isConstraint: true
        )
        let conflictNode = DependencyNode(
            group: group,
            artifact: artifact,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion
        )
        let root = DependencyNode(
            group: "com.example",
            artifact: "my-app",
            requestedVersion: "1.0.0",
            children: [constraintNode, conflictNode]
        )
        let conflict = DependencyConflict(
            coordinate: conflictCoordinate,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            requestedBy: "com.example:my-app"
        )
        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: [root],
            conflicts: [conflict]
        )
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
