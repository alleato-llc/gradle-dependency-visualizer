import SwiftUI
import GradleDependencyVisualizerCore

struct ModuleSelectionView: View {
    @Bindable var viewModel: ProjectSelectionViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            moduleList
            Divider()
            footer
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Select Modules")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading && viewModel.modulesTotal > 0 {
                    Text("Loading \(viewModel.modulesCompleted)/\(viewModel.modulesTotal)\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(viewModel.selectedModules.count)/\(viewModel.discoveredModules.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                TextField("Filter modules\u{2026}", text: $viewModel.moduleSearchText)
                    .textFieldStyle(.roundedBorder)

                Button(viewModel.selectedModules.count == viewModel.discoveredModules.count ? "Deselect All" : "Select All") {
                    viewModel.toggleSelectAllModules()
                }
            }
        }
        .padding()
    }

    private var moduleList: some View {
        List(viewModel.filteredModules) { module in
            HStack {
                Toggle(module.path, isOn: Binding(
                    get: { viewModel.selectedModules.contains(module.id) },
                    set: { isOn in
                        if isOn {
                            viewModel.selectedModules.insert(module.id)
                        } else {
                            viewModel.selectedModules.remove(module.id)
                        }
                    }
                ))
                .font(.body.monospaced())

                Spacer()

                moduleStatusIndicator(for: module.id)
            }
        }
    }

    @ViewBuilder
    private func moduleStatusIndicator(for moduleId: String) -> some View {
        switch viewModel.moduleLoadStatus[moduleId] {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed(let reason):
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .help(reason)
        case nil:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.isLoading && viewModel.modulesTotal > 0 {
                ProgressView(
                    value: Double(viewModel.modulesCompleted),
                    total: Double(viewModel.modulesTotal)
                )
                .frame(maxWidth: 200)

                Text("\(viewModel.modulesCompleted)/\(viewModel.modulesTotal) modules scanned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let summary = viewModel.loadSummary {
                Label(summary, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button {
                viewModel.loadDependencies()
            } label: {
                if viewModel.isLoading && viewModel.modulesTotal == 0 {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Load \(viewModel.selectedModules.count) Modules")
                }
            }
            .disabled(viewModel.selectedModules.isEmpty || viewModel.isLoading)
        }
        .padding()
    }
}
