import SwiftUI
import GradleDependencyVisualizerCore

struct ScopeValidationView: View {
    @Bindable var viewModel: ScopeValidationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scope Validation")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.results.count) issue(s)")
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

                TableColumn("Version") { result in
                    Text(result.version)
                        .font(.caption)
                }
                .width(min: 80)

                TableColumn("Detected As") { result in
                    Text(result.matchedLibrary)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .width(min: 120)

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
