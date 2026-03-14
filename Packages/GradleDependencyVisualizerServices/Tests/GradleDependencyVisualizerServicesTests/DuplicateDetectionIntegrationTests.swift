import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

/// Integration tests that verify the full duplicate detection pipeline:
/// parse real Gradle output → assemble multi-module tree → detect duplicates.
/// Uses actual `gradle dependencies` output fragments from typical Spring Boot
/// multi-module projects.
@Suite
struct DuplicateDetectionIntegrationTests {
    let parser = TextGradleDependencyParser()

    // MARK: - Fixtures

    /// Module `:app` — Spring Boot web app with Jackson, Guava, and SLF4J.
    static let appModuleOutput = """
    +--- org.springframework.boot:spring-boot-starter-web -> 3.5.11
    |    +--- org.springframework.boot:spring-boot-starter:3.5.11
    |    |    +--- org.springframework.boot:spring-boot:3.5.11
    |    |    |    +--- org.springframework:spring-core:6.2.16
    |    |    |    |    \\--- org.springframework:spring-jcl:6.2.16
    |    |    |    \\--- org.springframework:spring-context:6.2.16
    |    |    +--- org.springframework.boot:spring-boot-starter-logging:3.5.11
    |    |    |    +--- ch.qos.logback:logback-classic:1.5.32
    |    |    |    |    \\--- org.slf4j:slf4j-api:2.0.17
    |    |    |    \\--- org.slf4j:jul-to-slf4j:2.0.17
    |    |    \\--- org.yaml:snakeyaml:2.4
    |    \\--- org.springframework.boot:spring-boot-starter-json:3.5.11
    |         +--- com.fasterxml.jackson.core:jackson-databind:2.19.4
    |         |    +--- com.fasterxml.jackson.core:jackson-annotations:2.19.4
    |         |    \\--- com.fasterxml.jackson.core:jackson-core:2.19.4
    |         \\--- com.fasterxml.jackson.datatype:jackson-datatype-jdk8:2.19.4
    +--- com.google.guava:guava:31.1-jre
    |    +--- com.google.guava:failureaccess:1.0.2
    |    \\--- com.google.code.findbugs:jsr305:3.0.2
    \\--- org.slf4j:slf4j-api:2.0.16 -> 2.0.17
    """

    /// Module `:core` — shared library with Guava (different version), Jackson,
    /// and Apache Commons.
    static let coreModuleOutput = """
    +--- com.google.guava:guava:30.0-jre
    |    +--- com.google.guava:failureaccess:1.0.2
    |    \\--- com.google.code.findbugs:jsr305:3.0.2
    +--- com.fasterxml.jackson.core:jackson-databind:2.18.0
    |    +--- com.fasterxml.jackson.core:jackson-annotations:2.18.0
    |    \\--- com.fasterxml.jackson.core:jackson-core:2.18.0
    +--- org.apache.commons:commons-lang3:3.17.0
    \\--- org.slf4j:slf4j-api:2.0.17
    """

    /// Module `:data` — data access layer sharing Guava (same version as :core)
    /// and Spring Data.
    static let dataModuleOutput = """
    +--- com.google.guava:guava:30.0-jre
    |    +--- com.google.guava:failureaccess:1.0.2
    |    \\--- com.google.code.findbugs:jsr305:3.0.2
    +--- org.springframework.data:spring-data-jpa:3.5.9
    |    +--- org.springframework.data:spring-data-commons:3.5.9
    |    \\--- org.springframework:spring-core:6.2.16
    \\--- org.slf4j:slf4j-api:2.0.17
    """

    /// build.gradle content for :app module with a duplicate declaration.
    static let appBuildGradle = """
    plugins {
        id 'org.springframework.boot'
        id 'java'
    }

    dependencies {
        implementation 'org.springframework.boot:spring-boot-starter-web:3.5.11'
        implementation 'com.google.guava:guava:31.1-jre'
        implementation 'org.slf4j:slf4j-api:2.0.16'
        testImplementation 'com.google.guava:guava:31.1-jre'
    }
    """

    /// build.gradle content for :core module — no duplicates.
    static let coreBuildGradle = """
    plugins {
        id 'java-library'
    }

    dependencies {
        api 'com.google.guava:guava:30.0-jre'
        implementation 'com.fasterxml.jackson.core:jackson-databind:2.18.0'
        implementation 'org.apache.commons:commons-lang3:3.17.0'
        implementation 'org.slf4j:slf4j-api:2.0.17'
    }
    """

    // MARK: - Helpers

    private func assembleMultiModuleTree(
        modules: [(GradleModule, String)]
    ) -> DependencyTree {
        let moduleTrees = modules.map { (module, output) in
            let tree = parser.parse(
                output: output,
                projectName: "multi-module-project",
                configuration: .compileClasspath
            )
            return (module: module, tree: tree)
        }
        return MultiModuleTreeCalculator.assemble(
            projectName: "multi-module-project",
            configuration: .compileClasspath,
            moduleTrees: moduleTrees
        )
    }

    private func createTempProject(
        modules: [(name: String, path: String, buildContent: String)]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for module in modules {
            let relativePath = String(module.path.dropFirst()).replacingOccurrences(of: ":", with: "/")
            let moduleDir = tempDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: moduleDir, withIntermediateDirectories: true)
            try module.buildContent.write(
                to: moduleDir.appendingPathComponent("build.gradle"),
                atomically: true,
                encoding: .utf8
            )
        }

        return tempDir
    }

    // MARK: - Cross-module: parse → assemble → detect

    @Test
    func fullPipelineDetectsCrossModuleDuplicates() {
        let appModule = GradleModule(name: "app", path: ":app")
        let coreModule = GradleModule(name: "core", path: ":core")

        let tree = assembleMultiModuleTree(modules: [
            (appModule, Self.appModuleOutput),
            (coreModule, Self.coreModuleOutput),
        ])

        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)

        // Guava and slf4j-api are direct dependencies in both modules.
        // jackson-databind is transitive in :app (under starter-json), so not flagged.
        let coordinates = Set(results.map(\.coordinate))
        #expect(coordinates.contains("com.google.guava:guava"))
        #expect(coordinates.contains("org.slf4j:slf4j-api"))
        #expect(!coordinates.contains("com.fasterxml.jackson.core:jackson-databind"))
    }

    @Test
    func fullPipelineDetectsVersionMismatch() {
        let appModule = GradleModule(name: "app", path: ":app")
        let coreModule = GradleModule(name: "core", path: ":core")

        let tree = assembleMultiModuleTree(modules: [
            (appModule, Self.appModuleOutput),
            (coreModule, Self.coreModuleOutput),
        ])

        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)

        // Guava: app uses 31.1-jre, core uses 30.0-jre
        let guava = results.first { $0.coordinate == "com.google.guava:guava" }
        #expect(guava != nil)
        #expect(guava?.hasVersionMismatch == true)
        #expect(guava?.versions["app"] == "31.1-jre")
        #expect(guava?.versions["core"] == "30.0-jre")
        #expect(guava?.recommendation.contains("mismatch") == true)

        // SLF4J: app's root declares 2.0.16 (resolved to 2.0.17 via conflict),
        // core declares 2.0.17. Cross-module compares the version on the direct
        // child node, so app's is the resolved 2.0.17 matching core's 2.0.17.
        let slf4j = results.first { $0.coordinate == "org.slf4j:slf4j-api" }
        #expect(slf4j != nil)
    }

    @Test
    func fullPipelineThreeModulesSharedDependency() {
        let appModule = GradleModule(name: "app", path: ":app")
        let coreModule = GradleModule(name: "core", path: ":core")
        let dataModule = GradleModule(name: "data", path: ":data")

        let tree = assembleMultiModuleTree(modules: [
            (appModule, Self.appModuleOutput),
            (coreModule, Self.coreModuleOutput),
            (dataModule, Self.dataModuleOutput),
        ])

        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)

        // Guava appears in all 3 modules
        let guava = results.first { $0.coordinate == "com.google.guava:guava" }
        #expect(guava != nil)
        #expect(guava?.modules.count == 3)
        #expect(Set(guava?.modules ?? []) == Set(["app", "core", "data"]))

        // SLF4J also in all 3
        let slf4j = results.first { $0.coordinate == "org.slf4j:slf4j-api" }
        #expect(slf4j != nil)
        #expect(slf4j?.modules.count == 3)
    }

    @Test
    func fullPipelineNoDuplicatesForUniqueModules() {
        // app has spring-boot-starter-web, core has commons-lang3 — no overlap at root level
        let appOnly = """
        \\--- org.springframework.boot:spring-boot-starter-web:3.5.11
        """
        let coreOnly = """
        \\--- org.apache.commons:commons-lang3:3.17.0
        """

        let tree = assembleMultiModuleTree(modules: [
            (GradleModule(name: "app", path: ":app"), appOnly),
            (GradleModule(name: "core", path: ":core"), coreOnly),
        ])

        let results = DuplicateDependencyCalculator.detectCrossModule(tree: tree)
        #expect(results.isEmpty)
    }

    // MARK: - Within-module: build file parsing → detect

    @Test
    func fullPipelineDetectsWithinModuleDuplicates() throws {
        let tempDir = try createTempProject(modules: [
            (name: "app", path: ":app", buildContent: Self.appBuildGradle),
            (name: "core", path: ":core", buildContent: Self.coreBuildGradle),
        ])
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modules = [
            GradleModule(name: "app", path: ":app"),
            GradleModule(name: "core", path: ":core"),
        ]

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: modules
        )

        // :app has guava declared twice (implementation + testImplementation)
        #expect(results.count == 1)
        #expect(results[0].coordinate == "com.google.guava:guava")
        #expect(results[0].kind == DuplicateDependencyResult.DuplicateKind.withinModule)
        #expect(results[0].modules == ["app"])
        #expect(results[0].recommendation.contains("app"))
        #expect(results[0].recommendation.contains("2"))
    }

    @Test
    func fullPipelineNoWithinModuleDuplicatesForCleanFiles() throws {
        let tempDir = try createTempProject(modules: [
            (name: "core", path: ":core", buildContent: Self.coreBuildGradle),
        ])
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modules = [GradleModule(name: "core", path: ":core")]

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: modules
        )

        #expect(results.isEmpty)
    }

    // MARK: - Combined: full detect() pipeline

    @Test
    func fullPipelineCombinedDetection() throws {
        let appModule = GradleModule(name: "app", path: ":app")
        let coreModule = GradleModule(name: "core", path: ":core")

        let tree = assembleMultiModuleTree(modules: [
            (appModule, Self.appModuleOutput),
            (coreModule, Self.coreModuleOutput),
        ])

        let tempDir = try createTempProject(modules: [
            (name: "app", path: ":app", buildContent: Self.appBuildGradle),
            (name: "core", path: ":core", buildContent: Self.coreBuildGradle),
        ])
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let results = DuplicateDependencyCalculator.detect(
            tree: tree,
            projectPath: tempDir.path,
            modules: [appModule, coreModule]
        )

        // Should have both cross-module and within-module results
        let crossModule = results.filter { $0.kind == .crossModule }
        let withinModule = results.filter { $0.kind == .withinModule }

        #expect(!crossModule.isEmpty)
        #expect(!withinModule.isEmpty)

        // Guava appears in both categories
        #expect(crossModule.contains { $0.coordinate == "com.google.guava:guava" })
        #expect(withinModule.contains { $0.coordinate == "com.google.guava:guava" })

        // Results are sorted by coordinate
        let coordinates = results.map(\.coordinate)
        #expect(coordinates == coordinates.sorted())
    }

    @Test
    func fullPipelineSingleModuleProjectSkipsCrossModule() throws {
        let tree = parser.parse(
            output: Self.appModuleOutput,
            projectName: "single-module",
            configuration: .compileClasspath
        )

        let tempDir = try createTempProject(modules: [
            (name: "root", path: ":", buildContent: Self.appBuildGradle),
        ])
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Single-module: build file is at projectPath root
        let rootBuildContent = Self.appBuildGradle
        try rootBuildContent.write(
            to: URL(fileURLWithPath: tempDir.path).appendingPathComponent("build.gradle"),
            atomically: true,
            encoding: .utf8
        )

        let results = DuplicateDependencyCalculator.detect(
            tree: tree,
            projectPath: tempDir.path,
            modules: []
        )

        // No synthetic module nodes → no cross-module results
        let crossModule = results.filter { $0.kind == .crossModule }
        #expect(crossModule.isEmpty)

        // Within-module should still find guava duplicate
        let withinModule = results.filter { $0.kind == .withinModule }
        #expect(withinModule.contains { $0.coordinate == "com.google.guava:guava" })
    }

    // MARK: - Build file parsing integrated with real patterns

    @Test
    func kotlinDslBuildFileIntegration() throws {
        let ktsBuildContent = """
        plugins {
            id("org.springframework.boot")
            kotlin("jvm")
        }

        dependencies {
            implementation("com.google.guava:guava:31.1-jre")
            implementation("org.springframework.boot:spring-boot-starter-web:3.5.11")
            testImplementation("com.google.guava:guava:31.1-jre")
            testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
        }
        """

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try ktsBuildContent.write(
            to: tempDir.appendingPathComponent("build.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: []
        )

        #expect(results.count == 1)
        #expect(results[0].coordinate == "com.google.guava:guava")
    }

    @Test
    func buildFileWithCommentsIgnored() throws {
        let buildContent = """
        dependencies {
            implementation 'com.google.guava:guava:31.1-jre'
            // implementation 'com.google.guava:guava:31.1-jre'
            /*
            implementation 'com.google.guava:guava:31.1-jre'
            */
        }
        """

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try buildContent.write(
            to: tempDir.appendingPathComponent("build.gradle"),
            atomically: true,
            encoding: .utf8
        )

        let results = DuplicateDependencyCalculator.detectWithinModule(
            projectPath: tempDir.path,
            modules: []
        )

        // Only one real declaration, commented ones should be ignored
        #expect(results.isEmpty)
    }
}
