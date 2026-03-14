import SwiftUI
import GradleDependencyVisualizerCore

struct DuplicateDetectionView: View {
    @Bindable var viewModel: DuplicateDetectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Duplicate Dependencies")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.results.count) duplicate(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Export JSON") {
                    viewModel.exportAsJSON()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Table(viewModel.sortedResults) {
                TableColumn("Dependency") { result in
                    Text(result.coordinate)
                        .font(.caption)
                }
                .width(min: 200)

                TableColumn("Type") { result in
                    Text(result.kind == .crossModule ? "Cross-module" : "Within-module")
                        .font(.caption)
                        .foregroundStyle(result.kind == .crossModule ? .blue : .purple)
                }
                .width(min: 100)

                TableColumn("Modules") { result in
                    Text(result.modules.joined(separator: ", "))
                        .font(.caption)
                }
                .width(min: 120)

                TableColumn("Versions") { result in
                    let versionValues = Array(Set(result.versions.values)).sorted()
                    Text(versionValues.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(result.hasVersionMismatch ? .red : .primary)
                }
                .width(min: 100)

                TableColumn("Recommendation") { result in
                    Text(result.recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(min: 200)
            }
        }
    }
}
