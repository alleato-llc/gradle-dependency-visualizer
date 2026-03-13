import SwiftUI
import GradleDependencyVisualizerCore

struct ContentView: View {
    let container: DependencyContainer
    @State private var projectSelectionViewModel: ProjectSelectionViewModel
    @State private var graphViewModel: DependencyGraphViewModel?
    @State private var conflictViewModel: ConflictTableViewModel?
    @State private var showConflicts = false

    init(container: DependencyContainer) {
        self.container = container
        self._projectSelectionViewModel = State(initialValue: ProjectSelectionViewModel(
            gradleRunner: container.gradleRunner,
            dependencyParser: container.dependencyParser
        ))
    }

    var body: some View {
        NavigationSplitView {
            ProjectSelectionView(viewModel: projectSelectionViewModel)
                .frame(minWidth: 250)
        } detail: {
            if let graphViewModel {
                VStack(spacing: 0) {
                    DependencyGraphView(viewModel: graphViewModel)

                    if showConflicts, let conflictViewModel {
                        Divider()
                        ConflictTableView(viewModel: conflictViewModel)
                            .frame(height: 200)
                    }
                }
                .toolbar {
                    if let conflictViewModel, !conflictViewModel.conflicts.isEmpty {
                        ToolbarItem {
                            Button(showConflicts ? "Hide Conflicts" : "View Conflicts") {
                                showConflicts.toggle()
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Select or drop a Gradle project folder to visualize its dependencies.")
                )
            }
        }
        .onChange(of: projectSelectionViewModel.dependencyTree) { _, tree in
            if let tree {
                graphViewModel = DependencyGraphViewModel(tree: tree, fileExporter: container.fileExporter)
                conflictViewModel = ConflictTableViewModel(tree: tree, fileExporter: container.fileExporter)
                showConflicts = false
            } else {
                graphViewModel = nil
                conflictViewModel = nil
            }
        }
    }
}
