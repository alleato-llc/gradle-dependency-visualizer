import SwiftUI
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

struct ContentView: View {
    enum DetailViewMode: String { case graph, table }

    let container: DependencyContainer
    @State private var projectSelectionViewModel: ProjectSelectionViewModel
    @State private var graphViewModel: DependencyGraphViewModel?
    @State private var conflictViewModel: ConflictTableViewModel?
    @State private var diffViewModel: DependencyDiffViewModel?
    @State private var tableViewModel: DependencyTableViewModel?
    @State private var scopeValidationViewModel: ScopeValidationViewModel?
    @State private var duplicateDetectionViewModel: DuplicateDetectionViewModel?
    @State private var showConflicts = false
    @State private var showScopeValidation = false
    @State private var showDuplicates = false
    @State private var detailMode: DetailViewMode = .graph

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
                Group {
                    switch detailMode {
                    case .graph:
                        VSplitView {
                            DependencyGraphView(viewModel: graphViewModel, onCompare: compareAgainstBaseline)
                                .frame(minHeight: 200)

                            if showConflicts, let conflictViewModel {
                                ConflictTableView(viewModel: conflictViewModel)
                                    .frame(minHeight: 100, idealHeight: 200)
                            }

                            if showScopeValidation, let scopeValidationViewModel {
                                ScopeValidationView(viewModel: scopeValidationViewModel)
                                    .frame(minHeight: 100, idealHeight: 200)
                            }

                            if showDuplicates, let duplicateDetectionViewModel {
                                DuplicateDetectionView(viewModel: duplicateDetectionViewModel)
                                    .frame(minHeight: 100, idealHeight: 200)
                            }
                        }
                    case .table:
                        if let tableViewModel {
                            DependencyTableView(viewModel: tableViewModel)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Picker("View", selection: $detailMode) {
                            Text("Graph").tag(DetailViewMode.graph)
                            Text("Table").tag(DetailViewMode.table)
                        }
                        .pickerStyle(.segmented)
                    }
                    if let conflictViewModel, !conflictViewModel.conflicts.isEmpty, detailMode == .graph {
                        ToolbarItem {
                            Button(showConflicts ? "Hide Conflicts" : "View Conflicts") {
                                showConflicts.toggle()
                            }
                        }
                    }
                    if let scopeValidationViewModel, !scopeValidationViewModel.results.isEmpty, detailMode == .graph {
                        ToolbarItem {
                            Button(showScopeValidation ? "Hide Validation" : "Validate Scopes") {
                                showScopeValidation.toggle()
                            }
                        }
                    }
                    if detailMode == .graph {
                        ToolbarItem {
                            Button(showDuplicates ? "Hide Duplicates" : "Detect Duplicates") {
                                if !showDuplicates {
                                    if duplicateDetectionViewModel == nil, let tree = projectSelectionViewModel.dependencyTree {
                                        duplicateDetectionViewModel = DuplicateDetectionViewModel(
                                            tree: tree,
                                            fileExporter: container.fileExporter,
                                            projectPath: projectSelectionViewModel.projectPath,
                                            modules: projectSelectionViewModel.discoveredModules
                                        )
                                    }
                                    duplicateDetectionViewModel?.detect()
                                }
                                showDuplicates.toggle()
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Select or drop a Gradle project folder or build.gradle(.kts) file to visualize its dependencies.")
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
                tableViewModel = DependencyTableViewModel(tree: tree, fileExporter: container.fileExporter)
                scopeValidationViewModel = ScopeValidationViewModel(tree: tree, fileExporter: container.fileExporter)
                duplicateDetectionViewModel = nil
                showConflicts = false
                showScopeValidation = false
                showDuplicates = false
                diffViewModel = nil
                // Default to table view for very large trees
                detailMode = tree.totalNodeCount > 5000 ? .table : .graph
            } else {
                graphViewModel = nil
                conflictViewModel = nil
                tableViewModel = nil
                scopeValidationViewModel = nil
                duplicateDetectionViewModel = nil
                diffViewModel = nil
            }
        }
    }

    private func compareAgainstBaseline() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, .plainText]
        panel.message = "Select a baseline dependency tree file (JSON or Gradle text output)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let baseline = try TreeImporter.importTree(
                from: data,
                fileName: url.lastPathComponent,
                fallbackConfiguration: projectSelectionViewModel.selectedConfiguration
            )
            guard let currentTree = projectSelectionViewModel.dependencyTree else { return }
            diffViewModel = DependencyDiffViewModel(
                baseline: baseline, current: currentTree, fileExporter: container.fileExporter
            )
        } catch {
            projectSelectionViewModel.errorPresenter.present(error)
        }
    }
}
