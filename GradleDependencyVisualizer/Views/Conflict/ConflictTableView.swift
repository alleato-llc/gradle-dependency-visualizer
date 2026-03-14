import SwiftUI
import GradleDependencyVisualizerCore

private func riskColor(for level: RiskLevel) -> Color {
    switch level {
    case .critical: .red
    case .high: .orange
    case .medium: .yellow
    case .low: .green
    case .info: .gray
    }
}

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

                TableColumn("Risk") { conflict in
                    if let riskLevel = conflict.riskLevel {
                        Text(riskLevel.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(riskColor(for: riskLevel))
                    } else {
                        Text("-")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 70)
            }
        }
    }
}
