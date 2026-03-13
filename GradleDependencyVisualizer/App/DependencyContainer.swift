import GradleDependencyVisualizerServices

@MainActor
struct DependencyContainer {
    let gradleRunner: any GradleRunner
    let dependencyParser: any GradleDependencyParser
    let fileExporter: any FileExporter

    init() {
        self.gradleRunner = ProcessGradleRunner()
        self.dependencyParser = TextGradleDependencyParser()
        self.fileExporter = PanelFileExporter()
    }

    init(gradleRunner: any GradleRunner, dependencyParser: any GradleDependencyParser, fileExporter: any FileExporter) {
        self.gradleRunner = gradleRunner
        self.dependencyParser = dependencyParser
        self.fileExporter = fileExporter
    }
}
