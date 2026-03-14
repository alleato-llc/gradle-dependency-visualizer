import Testing
import GradleDependencyVisualizerServices

@Suite
struct GradleBuildFileParserTests {
    @Test
    func parsesGroovySingleQuote() {
        let content = "implementation 'com.google.guava:guava:31.1-jre'"
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].configuration == "implementation")
        #expect(results[0].group == "com.google.guava")
        #expect(results[0].artifact == "guava")
        #expect(results[0].version == "31.1-jre")
    }

    @Test
    func parsesGroovyDoubleQuote() {
        let content = """
        implementation "org.springframework:spring-core:5.3.20"
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].group == "org.springframework")
        #expect(results[0].artifact == "spring-core")
        #expect(results[0].version == "5.3.20")
    }

    @Test
    func parsesKotlinDSL() {
        let content = """
        implementation("com.google.guava:guava:31.1-jre")
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].configuration == "implementation")
        #expect(results[0].group == "com.google.guava")
        #expect(results[0].artifact == "guava")
        #expect(results[0].version == "31.1-jre")
    }

    @Test
    func parsesGroovyMapNotation() {
        let content = """
        implementation group: 'com.google.guava', name: 'guava', version: '31.1-jre'
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].group == "com.google.guava")
        #expect(results[0].artifact == "guava")
        #expect(results[0].version == "31.1-jre")
    }

    @Test
    func parsesMultipleConfigurations() {
        let content = """
        implementation 'com.google.guava:guava:31.1-jre'
        testImplementation 'junit:junit:4.13.2'
        api 'org.slf4j:slf4j-api:1.7.36'
        compileOnly 'org.projectlombok:lombok:1.18.24'
        runtimeOnly 'mysql:mysql-connector-java:8.0.30'
        annotationProcessor 'org.projectlombok:lombok:1.18.24'
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 6)
        let configs = Set(results.map(\.configuration))
        #expect(configs.contains("implementation"))
        #expect(configs.contains("testImplementation"))
        #expect(configs.contains("api"))
        #expect(configs.contains("compileOnly"))
        #expect(configs.contains("runtimeOnly"))
        #expect(configs.contains("annotationProcessor"))
    }

    @Test
    func tracksLineNumbers() {
        let content = """
        plugins {
            id 'java'
        }

        dependencies {
            implementation 'com.google.guava:guava:31.1-jre'
            testImplementation 'junit:junit:4.13.2'
        }
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 2)
        #expect(results[0].line == 6)
        #expect(results[1].line == 7)
    }

    @Test
    func ignoresComments() {
        let content = """
        // implementation 'com.google.guava:guava:31.1-jre'
        implementation 'org.slf4j:slf4j-api:1.7.36'
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].group == "org.slf4j")
    }

    @Test
    func ignoresBlockComments() {
        let content = """
        /*
        implementation 'com.google.guava:guava:31.1-jre'
        */
        implementation 'org.slf4j:slf4j-api:1.7.36'
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.count == 1)
        #expect(results[0].group == "org.slf4j")
    }

    @Test
    func ignoresNonDependencyLines() {
        let content = """
        apply plugin: 'java'
        sourceCompatibility = '11'
        group = 'com.example'
        version = '1.0.0'
        """
        let results = GradleBuildFileParser.parseDependencies(from: content)
        #expect(results.isEmpty)
    }

    @Test
    func emptyContentReturnsEmpty() {
        let results = GradleBuildFileParser.parseDependencies(from: "")
        #expect(results.isEmpty)
    }
}
