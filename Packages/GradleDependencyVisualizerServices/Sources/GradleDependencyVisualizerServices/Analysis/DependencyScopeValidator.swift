import GradleDependencyVisualizerCore

public enum DependencyScopeValidator {
    private static let productionConfigurations: Set<GradleConfiguration> = [
        .compileClasspath, .runtimeClasspath, .implementation,
        .runtimeOnly, .compileOnly, .api,
    ]

    private static let testLibraries: [(group: String, artifact: String?, name: String)] = [
        // JUnit 4
        ("junit", "junit", "JUnit 4"),
        // JUnit 5
        ("org.junit.jupiter", nil, "JUnit 5"),
        ("org.junit.vintage", nil, "JUnit 5 Vintage"),
        ("org.junit.platform", nil, "JUnit Platform"),
        // TestNG
        ("org.testng", "testng", "TestNG"),
        // Spring Test
        ("org.springframework", "spring-test", "Spring Test"),
        ("org.springframework.boot", "spring-boot-test", "Spring Boot Test"),
        ("org.springframework.boot", "spring-boot-starter-test", "Spring Boot Starter Test"),
        // Mockito
        ("org.mockito", nil, "Mockito"),
        // MockK
        ("io.mockk", "mockk", "MockK"),
        ("io.mockk", "mockk-jvm", "MockK"),
        // AssertJ
        ("org.assertj", "assertj-core", "AssertJ"),
        // Hamcrest
        ("org.hamcrest", "hamcrest", "Hamcrest"),
        ("org.hamcrest", "hamcrest-core", "Hamcrest"),
        // EasyMock
        ("org.easymock", "easymock", "EasyMock"),
        // PowerMock
        ("org.powermock", nil, "PowerMock"),
        // WireMock
        ("com.github.tomakehurst", "wiremock", "WireMock"),
        ("org.wiremock", "wiremock", "WireMock"),
        // Arquillian
        ("org.jboss.arquillian", nil, "Arquillian"),
        // REST Assured
        ("io.rest-assured", nil, "REST Assured"),
        // Awaitility
        ("org.awaitility", "awaitility", "Awaitility"),
        // Testcontainers
        ("org.testcontainers", nil, "Testcontainers"),
        // Cucumber
        ("io.cucumber", nil, "Cucumber"),
        // Spock
        ("org.spockframework", nil, "Spock"),
        // JMockit
        ("org.jmockit", "jmockit", "JMockit"),
        // Google Truth
        ("com.google.truth", "truth", "Google Truth"),
        // JsonUnit
        ("net.javacrumbs.json-unit", nil, "JsonUnit"),
        // XMLUnit
        ("org.xmlunit", nil, "XMLUnit"),
        // DbUnit
        ("org.dbunit", "dbunit", "DbUnit"),
        // Selenide / Selenium
        ("com.codeborne", "selenide", "Selenide"),
        ("org.seleniumhq.selenium", nil, "Selenium"),
        // Robolectric
        ("org.robolectric", nil, "Robolectric"),
        // ArchUnit
        ("com.tngtech.archunit", nil, "ArchUnit"),
        // Pitest (mutation testing)
        ("org.pitest", nil, "Pitest"),
    ]

    public static func validate(tree: DependencyTree) -> [ScopeValidationResult] {
        guard productionConfigurations.contains(tree.configuration) else {
            return []
        }

        let allNodes = DependencyAnalysisCalculator.allNodes(from: tree)
        var results: [ScopeValidationResult] = []
        var seen: Set<String> = []

        for node in allNodes {
            let key = node.coordinate
            guard !seen.contains(key) else { continue }

            if let libraryName = matchTestLibrary(group: node.group, artifact: node.artifact) {
                seen.insert(key)
                results.append(ScopeValidationResult(
                    coordinate: node.coordinate,
                    version: node.resolvedVersion ?? node.requestedVersion,
                    matchedLibrary: libraryName,
                    configuration: tree.configuration,
                    recommendation: "Move to testImplementation or testRuntimeOnly"
                ))
            }
        }

        return results.sorted { $0.coordinate < $1.coordinate }
    }

    private static func matchTestLibrary(group: String, artifact: String) -> String? {
        for entry in testLibraries {
            if let expectedArtifact = entry.artifact {
                if group == entry.group && artifact == expectedArtifact {
                    return entry.name
                }
            } else {
                if group == entry.group || group.hasPrefix(entry.group + ".") {
                    return entry.name
                }
            }
        }
        return nil
    }
}
