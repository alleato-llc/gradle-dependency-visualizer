import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class DependencyDiffViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "DependencyDiff")
    private let fileExporter: any FileExporter

    let diffResult: DependencyDiffResult

    enum SortField: String {
        case status
        case coordinate
        case beforeVersion
        case afterVersion
    }

    var sortField: SortField = .coordinate
    var sortAscending = true
    var searchText = ""
    var showAdded = true
    var showRemoved = true
    var showChanged = true
    var showUnchanged = false

    var filteredEntries: [DependencyDiffEntry] {
        var entries = diffResult.entries

        entries = entries.filter { entry in
            switch entry.changeKind {
            case .added: return showAdded
            case .removed: return showRemoved
            case .versionChanged: return showChanged
            case .unchanged: return showUnchanged
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            entries = entries.filter { $0.coordinate.lowercased().contains(query) }
        }

        entries.sort { a, b in
            let result: Bool
            switch sortField {
            case .status:
                result = a.changeKind.rawValue < b.changeKind.rawValue
            case .coordinate:
                result = a.coordinate < b.coordinate
            case .beforeVersion:
                result = (a.effectiveBeforeVersion ?? "") < (b.effectiveBeforeVersion ?? "")
            case .afterVersion:
                result = (a.effectiveAfterVersion ?? "") < (b.effectiveAfterVersion ?? "")
            }
            return sortAscending ? result : !result
        }

        return entries
    }

    init(baseline: DependencyTree, current: DependencyTree, fileExporter: any FileExporter) {
        self.fileExporter = fileExporter
        self.diffResult = DependencyDiffCalculator.diff(baseline: baseline, current: current)
    }

    func toggleSort(field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }

    func exportDiffAsJSON() {
        let entries = filteredEntries.map { entry in
            var dict: [String: String] = [
                "coordinate": entry.coordinate,
                "status": entry.changeKind.rawValue,
            ]
            if let version = entry.effectiveBeforeVersion {
                dict["beforeVersion"] = version
            }
            if let version = entry.effectiveAfterVersion {
                dict["afterVersion"] = version
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        do {
            try fileExporter.saveData(data, defaultName: "\(diffResult.currentName)-diff.json", contentType: .json)
            logger.info("Diff exported successfully")
        } catch {
            logger.error("Failed to export diff: \(error.localizedDescription)")
        }
    }
}
