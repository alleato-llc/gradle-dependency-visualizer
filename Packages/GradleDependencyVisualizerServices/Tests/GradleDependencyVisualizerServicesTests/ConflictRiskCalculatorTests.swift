import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct ConflictRiskCalculatorTests {

    private func makeTree(
        requestedVersion: String,
        resolvedVersion: String,
        configuration: GradleConfiguration = .compileClasspath,
        roots: [DependencyNode]? = nil
    ) -> DependencyTree {
        let conflict = DependencyConflict(
            coordinate: "com.example:lib",
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            requestedBy: "com.example:app"
        )
        let defaultRoots = roots ?? [
            TestDependencyTreeFactory.makeNode(
                group: "com.example",
                artifact: "lib",
                requestedVersion: requestedVersion,
                resolvedVersion: resolvedVersion
            )
        ]
        return DependencyTree(
            projectName: "test-project",
            configuration: configuration,
            roots: defaultRoots,
            conflicts: [conflict]
        )
    }

    private func makeRunner() -> TestGradleRunner {
        TestGradleRunner()
    }

    @Test
    func majorVersionJumpIsHigh() async {
        let tree = makeTree(requestedVersion: "1.0.0", resolvedVersion: "2.0.0")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed.count == 1)
        #expect(assessed[0].riskLevel == .high)
        #expect(assessed[0].riskReason?.contains("Major version jump") == true)
    }

    @Test
    func minorVersionJumpIsMedium() async {
        let tree = makeTree(requestedVersion: "1.0.0", resolvedVersion: "1.5.0")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("Minor version jump") == true)
    }

    @Test
    func patchVersionBumpIsLow() async {
        let tree = makeTree(requestedVersion: "1.0.0", resolvedVersion: "1.0.5")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .low)
        #expect(assessed[0].riskReason?.contains("Patch version bump") == true)
    }

    @Test
    func qualifierOnlyIsInfo() async {
        let tree = makeTree(requestedVersion: "3.4.3.Final", resolvedVersion: "3.4.3.RELEASE")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .info)
        #expect(assessed[0].riskReason?.contains("Qualifier change only") == true)
    }

    @Test
    func bomManagedReducesRisk() async {
        let tree = TestDependencyTreeFactory.makeTreeWithBOMConstraints(
            conflictCoordinate: "org.slf4j:slf4j-api",
            requestedVersion: "1.7.36",
            resolvedVersion: "2.0.17"
        )
        let runner = makeRunner()
        runner.insightOutputs["org.slf4j:slf4j-api"] = "org.slf4j:slf4j-api:2.0.17 (selected by rule)\n   variant \"compile\" ["
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: runner, projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("BOM-managed") == true)
    }

    @Test
    func bomManagedViaConstraintOutput() async {
        let tree = TestDependencyTreeFactory.makeTreeWithBOMConstraints(
            conflictCoordinate: "org.slf4j:slf4j-api",
            requestedVersion: "1.7.36",
            resolvedVersion: "2.0.17"
        )
        let runner = makeRunner()
        runner.insightOutputs["org.slf4j:slf4j-api"] = "org.slf4j:slf4j-api:2.0.17 (by constraint)\n   variant \"compile\" ["
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: runner, projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("BOM-managed") == true)
    }

    @Test
    func bomManagedFallsBackToTreeHeuristic() async {
        // Runner returns empty string, so fallback to tree-based constraint detection
        let tree = TestDependencyTreeFactory.makeTreeWithBOMConstraints(
            conflictCoordinate: "org.slf4j:slf4j-api",
            requestedVersion: "1.7.36",
            resolvedVersion: "2.0.17"
        )
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("BOM-managed") == true)
    }

    @Test
    func downgradeIncreasesRisk() async {
        let tree = makeTree(requestedVersion: "2.0.0", resolvedVersion: "1.5.0")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        // Major diff = high, + downgrade = critical
        #expect(assessed[0].riskLevel == .critical)
        #expect(assessed[0].riskReason?.contains("downgrade detected") == true)
    }

    @Test
    func testScopeReducesRisk() async {
        let tree = makeTree(
            requestedVersion: "1.0.0",
            resolvedVersion: "2.0.0",
            configuration: .testCompileClasspath
        )
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        // Major diff = high, - test scope = medium
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("test scope") == true)
    }

    @Test
    func combinedAdjustments() async {
        // BOM + test scope both reduce
        let constraintNode = TestDependencyTreeFactory.makeNode(
            group: "org.slf4j",
            artifact: "slf4j-api",
            requestedVersion: "2.0.17",
            resolvedVersion: "2.0.17",
            isConstraint: true
        )
        let conflictNode = TestDependencyTreeFactory.makeNode(
            group: "org.slf4j",
            artifact: "slf4j-api",
            requestedVersion: "1.7.36",
            resolvedVersion: "2.0.17"
        )
        let root = TestDependencyTreeFactory.makeNode(
            group: "com.example",
            artifact: "app",
            requestedVersion: "1.0.0",
            children: [constraintNode, conflictNode]
        )
        let conflict = DependencyConflict(
            coordinate: "org.slf4j:slf4j-api",
            requestedVersion: "1.7.36",
            resolvedVersion: "2.0.17",
            requestedBy: "com.example:app"
        )
        let tree = DependencyTree(
            projectName: "test-project",
            configuration: .testCompileClasspath,
            roots: [root],
            conflicts: [conflict]
        )
        let runner = makeRunner()
        runner.insightOutputs["org.slf4j:slf4j-api"] = "org.slf4j:slf4j-api:2.0.17 (selected by rule)\n   variant \"compile\" ["
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: runner, projectPath: "/test")
        // Major = high (index 3), BOM -1 = medium (2), test scope -1 = low (1)
        #expect(assessed[0].riskLevel == .low)
        #expect(assessed[0].riskReason?.contains("BOM-managed") == true)
        #expect(assessed[0].riskReason?.contains("test scope") == true)
    }

    @Test
    func nonSemverHandledGracefully() async {
        let tree = makeTree(requestedVersion: "alpha", resolvedVersion: "beta")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("Unable to parse version") == true)
    }

    @Test
    func multiSegmentPatch() async {
        // 1.9.22.1 -> 1.9.25.1: same major+minor, different patch = .low
        let tree = makeTree(requestedVersion: "1.9.22.1", resolvedVersion: "1.9.25.1")
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .low)
        #expect(assessed[0].riskReason?.contains("Patch version bump") == true)
    }

    @Test
    func realSpringBootConflicts() async {
        // jackson-databind 2.13.0 -> 2.14.2: minor version jump = medium (production scope)
        let jacksonConflict = DependencyConflict(
            coordinate: "com.fasterxml.jackson.core:jackson-databind",
            requestedVersion: "2.13.0",
            resolvedVersion: "2.14.2",
            requestedBy: "org.springframework:spring-web"
        )
        let jacksonNode = TestDependencyTreeFactory.makeNode(
            group: "com.fasterxml.jackson.core",
            artifact: "jackson-databind",
            requestedVersion: "2.13.0",
            resolvedVersion: "2.14.2"
        )
        let tree = DependencyTree(
            projectName: "spring-app",
            configuration: .runtimeClasspath,
            roots: [jacksonNode],
            conflicts: [jacksonConflict]
        )
        let assessed = await ConflictRiskCalculator.assessConflicts(tree: tree, runner: makeRunner(), projectPath: "/test")
        #expect(assessed[0].riskLevel == .medium)
        #expect(assessed[0].riskReason?.contains("Minor version jump") == true)
    }
}
