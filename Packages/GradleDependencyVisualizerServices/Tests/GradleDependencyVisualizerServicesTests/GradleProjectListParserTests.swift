import Testing
@testable import GradleDependencyVisualizerServices

@Suite
struct GradleProjectListParserTests {
    @Test
    func parsesStandardProjectOutput() {
        let output = """
        > Task :projects

        ------------------------------------------------------------
        Root project 'my-project'
        ------------------------------------------------------------

        Root project 'my-project'
        +--- Project ':app'
        +--- Project ':core'
        \\--- Project ':data'

        To see a list of the tasks of a project, run gradlew <project-path>:tasks
        """

        let modules = GradleProjectListParser.parse(output: output)

        #expect(modules.count == 3)
        #expect(modules[0].name == "app")
        #expect(modules[0].path == ":app")
        #expect(modules[1].name == "core")
        #expect(modules[1].path == ":core")
        #expect(modules[2].name == "data")
        #expect(modules[2].path == ":data")
    }

    @Test
    func parsesNestedSubmodules() {
        let output = """
        Root project 'my-project'
        +--- Project ':app'
        +--- Project ':app:feature'
        \\--- Project ':app:feature:login'
        """

        let modules = GradleProjectListParser.parse(output: output)

        #expect(modules.count == 3)
        #expect(modules[0].name == "app")
        #expect(modules[0].path == ":app")
        #expect(modules[1].name == "feature")
        #expect(modules[1].path == ":app:feature")
        #expect(modules[2].name == "login")
        #expect(modules[2].path == ":app:feature:login")
    }

    @Test
    func noSubmodulesReturnsEmpty() {
        let output = """
        > Task :projects

        ------------------------------------------------------------
        Root project 'my-project'
        ------------------------------------------------------------

        Root project 'my-project' - A simple Gradle project
        No sub-projects

        To see a list of the tasks of a project, run gradlew <project-path>:tasks
        """

        let modules = GradleProjectListParser.parse(output: output)
        #expect(modules.isEmpty)
    }

    @Test
    func emptyOutputReturnsEmpty() {
        let modules = GradleProjectListParser.parse(output: "")
        #expect(modules.isEmpty)
    }
}
