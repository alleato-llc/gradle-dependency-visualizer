import SwiftUI
import GradleDependencyVisualizerCore

struct DependencyTableView: View {
    @Bindable var viewModel: DependencyTableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()
            if viewModel.tableMode == .flat {
                flatList
            } else {
                treeList
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("Mode", selection: $viewModel.tableMode) {
                Text("Flat").tag(DependencyTableViewModel.TableMode.flat)
                Text("Tree").tag(DependencyTableViewModel.TableMode.tree)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            TextField("Search dependencies\u{2026}", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Toggle("Conflicts Only", isOn: $viewModel.showConflictsOnly)
                .toggleStyle(.checkbox)

            Spacer()

            Text("\(viewModel.displayedFlatEntries.count) dependencies")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Export JSON") {
                viewModel.exportTableAsJSON()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var flatList: some View {
        List(viewModel.displayedFlatEntries) { entry in
            DisclosureGroup {
                ForEach(entry.usedBy, id: \.self) { parent in
                    HStack(spacing: 4) {
                        Text("Used by:")
                            .foregroundStyle(.secondary)
                        Text(parent)
                    }
                    .font(.caption)
                    .padding(.leading, 8)
                }
                if entry.versions.count > 1 {
                    HStack(spacing: 4) {
                        Text("Versions:")
                            .foregroundStyle(.secondary)
                        Text(entry.versions.sorted().joined(separator: ", "))
                    }
                    .font(.caption)
                    .padding(.leading, 8)
                }
            } label: {
                flatRow(entry: entry)
            }
        }
    }

    private func flatRow(entry: FlatDependencyEntry) -> some View {
        HStack {
            Text(entry.coordinate)
                .font(.body.monospaced())
                .foregroundStyle(entry.isOmitted ? .secondary : .primary)

            Text(entry.version)
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.occurrenceCount > 1 {
                Text("\u{00D7}\(entry.occurrenceCount)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if entry.hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
    }

    private var treeList: some View {
        List(viewModel.filteredRoots, children: \.optionalChildren) { node in
            treeRow(node: node)
        }
    }

    private func treeRow(node: DependencyNode) -> some View {
        HStack {
            Text(node.coordinate)
                .font(.body.monospaced())
                .foregroundStyle(node.isOmitted ? .secondary : .primary)

            Text(node.displayVersion)
                .font(.caption)
                .foregroundStyle(.secondary)

            if node.hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
    }
}
