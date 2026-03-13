import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerTestSupport
@testable import GradleDependencyVisualizer

@Suite
struct ProjectSelectionViewModelTests {
    @Test @MainActor
    func initialStateIsEmpty() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        #expect(viewModel.projectPath.isEmpty)
        #expect(viewModel.dependencyTree == nil)
        #expect(!viewModel.isLoading)
    }

    @Test @MainActor
    func loadDependenciesWithInvalidPathShowsError() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        viewModel.loadDependencies()
        #expect(viewModel.isShowingError)
    }

    @Test @MainActor
    func hasValidProjectReturnsFalseForEmptyPath() {
        let runner = TestGradleRunner()
        let parser = TestGradleDependencyParser()
        let viewModel = ProjectSelectionViewModel(gradleRunner: runner, dependencyParser: parser)

        #expect(!viewModel.hasValidProject)
    }
}
