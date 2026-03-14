import SwiftUI
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

struct ProjectSelectionView: View {
    @Bindable var viewModel: ProjectSelectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gradle Project")
                .font(.headline)

            DropTargetView(onDrop: { url in
                viewModel.handleDroppedURL(url)
            })

            HStack {
                TextField("Project path", text: $viewModel.projectPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    viewModel.selectProjectViaOpenPanel()
                }
            }

            Button("Import\u{2026}") {
                viewModel.importFromFile()
            }

            Picker("Configuration", selection: $viewModel.selectedConfiguration) {
                ForEach(GradleConfiguration.allCases, id: \.self) { config in
                    Text(config.displayName).tag(config)
                }
            }

            Text(viewModel.selectedConfiguration.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("Configuration Guide") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(GradleConfiguration.allCases, id: \.self) { config in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.displayName)
                                .font(.caption.bold())
                            Text(config.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)

            HStack {
                Button("Discover Modules") {
                    viewModel.discoverModules()
                }
                .disabled(!viewModel.hasValidProject || viewModel.isLoading)
            }

            if !viewModel.isMultiModule {
                Button {
                    viewModel.loadDependencies()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Load Dependencies")
                    }
                }
                .disabled(!viewModel.hasValidProject || viewModel.isLoading)
            }

            if let tree = viewModel.dependencyTree {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(tree.totalNodeCount) dependencies")
                        .font(.caption)
                    Text("\(DependencyAnalysisCalculator.uniqueCoordinates(from: tree).count) distinct dependencies")
                        .font(.caption)
                    Text("Max depth: \(tree.maxDepth)")
                        .font(.caption)
                    if !tree.conflicts.isEmpty {
                        Text("\(tree.conflicts.count) conflict(s)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .alert("Error", isPresented: $viewModel.isShowingError) {
            Button("OK") { viewModel.isShowingError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

}
