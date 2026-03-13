import SwiftUI
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

struct ContentView: View {
    let container: DependencyContainer
    @State private var projectSelectionViewModel: ProjectSelectionViewModel
    @State private var graphViewModel: DependencyGraphViewModel?
    @State private var conflictViewModel: ConflictTableViewModel?
    @State private var diffViewModel: DependencyDiffViewModel?
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
            if let diffViewModel {
                DependencyDiffView(viewModel: diffViewModel, onDismiss: {
                    self.diffViewModel = nil
                })
            } else if let graphViewModel {
                VSplitView {
                    DependencyGraphView(viewModel: graphViewModel, onCompare: compareAgainstBaseline)
                        .frame(minHeight: 200)

                    if showConflicts, let conflictViewModel {
                        ConflictTableView(viewModel: conflictViewModel)
                            .frame(minHeight: 100, idealHeight: 200)
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
                    description: Text("Select or drop a Gradle project folder or build.gradle file to visualize its dependencies.")
                )
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            Task { @MainActor in
                                _ = projectSelectionViewModel.handleDroppedURL(url)
                            }
                        }
                    }
                    return true
                }
            }
        }
        .onChange(of: projectSelectionViewModel.dependencyTree) { _, tree in
            if let tree {
                graphViewModel = DependencyGraphViewModel(tree: tree, fileExporter: container.fileExporter)
                conflictViewModel = ConflictTableViewModel(tree: tree, fileExporter: container.fileExporter)
                showConflicts = false
                diffViewModel = nil
            } else {
                graphViewModel = nil
                conflictViewModel = nil
                diffViewModel = nil
            }
        }
    }

    private func compareAgainstBaseline() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.message = "Select a baseline dependency tree JSON"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let baseline = try JsonTreeImporter.importTree(from: data)
            guard let currentTree = projectSelectionViewModel.dependencyTree else { return }
            diffViewModel = DependencyDiffViewModel(
                baseline: baseline, current: currentTree, fileExporter: container.fileExporter
            )
        } catch {
            projectSelectionViewModel.errorPresenter.present(error)
        }
    }
}
