import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class DependencyTableViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "DependencyTable")
    private let fileExporter: any FileExporter

    let tree: DependencyTree
    let flatEntries: [FlatDependencyEntry]

    enum TableMode: String, CaseIterable {
        case flat
        case tree
    }

    enum SortField: String {
        case coordinate
        case version
        case occurrences
        case group
    }

    var tableMode: TableMode = .flat
    var searchText = ""
    var sortField: SortField = .coordinate
    var sortAscending = true
    var showConflictsOnly = false

    var displayedFlatEntries: [FlatDependencyEntry] {
        var entries = flatEntries

        if showConflictsOnly {
            entries = entries.filter(\.hasConflict)
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            entries = entries.filter { $0.coordinate.lowercased().contains(query) }
        }

        entries.sort { a, b in
            let result: Bool
            switch sortField {
            case .coordinate:
                result = a.coordinate < b.coordinate
            case .version:
                result = a.version < b.version
            case .occurrences:
                result = a.occurrenceCount < b.occurrenceCount
            case .group:
                result = a.group < b.group
            }
            return sortAscending ? result : !result
        }

        return entries
    }

    var filteredRoots: [DependencyNode] {
        tree.roots
    }

    init(tree: DependencyTree, fileExporter: any FileExporter) {
        self.tree = tree
        self.fileExporter = fileExporter
        self.flatEntries = DependencyTableCalculator.flatEntries(from: tree)
    }

    func toggleSort(field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }

    func exportTableAsJSON() {
        let entries = displayedFlatEntries.map { entry in
            [
                "coordinate": entry.coordinate,
                "group": entry.group,
                "artifact": entry.artifact,
                "version": entry.version,
                "hasConflict": String(entry.hasConflict),
                "occurrenceCount": String(entry.occurrenceCount),
                "usedBy": entry.usedBy.joined(separator: ", "),
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        do {
            try fileExporter.saveData(data, defaultName: "\(tree.projectName)-dependencies.json", contentType: .json)
            logger.info("Dependency table exported successfully")
        } catch {
            logger.error("Failed to export dependency table: \(error.localizedDescription)")
        }
    }
}
