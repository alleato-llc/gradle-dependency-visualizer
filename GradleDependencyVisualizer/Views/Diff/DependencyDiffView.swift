import SwiftUI
import GradleDependencyVisualizerCore

struct DependencyDiffView: View {
    @Bindable var viewModel: DependencyDiffViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            diffTable
        }
    }

    private var header: some View {
        HStack {
            Text("Dependency Diff")
                .font(.headline)

            directionIndicator

            Spacer()

            summaryText

            Button("Export JSON") {
                viewModel.exportDiffAsJSON()
            }

            Button("Back to Graph") {
                onDismiss()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var directionIndicator: some View {
        HStack(spacing: 4) {
            Text(viewModel.diffResult.baselineName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: { viewModel.swapDirection() }) {
                Image(systemName: "arrow.right.arrow.left")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Swap comparison direction")
            Text(viewModel.diffResult.currentName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryText: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.diffResult.entries.count) distinct dependencies:")
                .foregroundStyle(.secondary)
            Text("\(viewModel.diffResult.added.count) added")
                .foregroundStyle(.green)
            Text("\u{00B7}")
                .foregroundStyle(.secondary)
            Text("\(viewModel.diffResult.removed.count) removed")
                .foregroundStyle(.red)
            Text("\u{00B7}")
                .foregroundStyle(.secondary)
            Text("\(viewModel.diffResult.versionChanged.count) changed")
                .foregroundStyle(.orange)
            Text("\u{00B7}")
                .foregroundStyle(.secondary)
            Text("\(viewModel.diffResult.unchanged.count) unchanged")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var filterBar: some View {
        HStack {
            Toggle("Added", isOn: $viewModel.showAdded)
                .toggleStyle(.checkbox)
            Toggle("Removed", isOn: $viewModel.showRemoved)
                .toggleStyle(.checkbox)
            Toggle("Changed", isOn: $viewModel.showChanged)
                .toggleStyle(.checkbox)
            Toggle("Unchanged", isOn: $viewModel.showUnchanged)
                .toggleStyle(.checkbox)

            Spacer()

            TextField("Search dependencies…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var diffTable: some View {
        Table(viewModel.filteredEntries) {
            TableColumn("Status") { entry in
                Text(statusLabel(for: entry.changeKind))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: entry.changeKind))
            }
            .width(min: 80, max: 100)

            TableColumn("Dependency") { entry in
                Text(entry.coordinate)
                    .font(.caption)
            }
            .width(min: 200)

            TableColumn("Before") { entry in
                Text(entry.effectiveBeforeVersion ?? "\u{2014}")
                    .font(.caption)
                    .foregroundStyle(entry.beforeVersion == nil ? .secondary : .primary)
            }
            .width(min: 100)

            TableColumn("After") { entry in
                Text(entry.effectiveAfterVersion ?? "\u{2014}")
                    .font(.caption)
                    .foregroundStyle(entry.afterVersion == nil ? .secondary : .primary)
            }
            .width(min: 100)
        }
    }

    private func statusLabel(for kind: DependencyDiffEntry.ChangeKind) -> String {
        switch kind {
        case .added: return "+ Added"
        case .removed: return "- Removed"
        case .versionChanged: return "~ Changed"
        case .unchanged: return "= Unchanged"
        }
    }

    private func statusColor(for kind: DependencyDiffEntry.ChangeKind) -> Color {
        switch kind {
        case .added: return .green
        case .removed: return .red
        case .versionChanged: return .orange
        case .unchanged: return .secondary
        }
    }
}
