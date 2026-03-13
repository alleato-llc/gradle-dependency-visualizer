import SwiftUI
import GradleDependencyVisualizerCore

struct ConflictTableView: View {
    @Bindable var viewModel: ConflictTableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Dependency Conflicts")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.conflicts.count) conflict(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Export JSON") {
                    viewModel.exportConflictsAsJSON()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Table(viewModel.sortedConflicts) {
                TableColumn("Dependency") { conflict in
                    Text(conflict.coordinate)
                        .font(.caption)
                }
                .width(min: 200)

                TableColumn("Requested") { conflict in
                    Text(conflict.requestedVersion)
                        .font(.caption)
                }
                .width(min: 80)

                TableColumn("Resolved") { conflict in
                    Text(conflict.resolvedVersion)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .width(min: 80)

                TableColumn("Requested By") { conflict in
                    Text(conflict.requestedBy)
                        .font(.caption)
                }
                .width(min: 200)
            }
        }
    }
}
