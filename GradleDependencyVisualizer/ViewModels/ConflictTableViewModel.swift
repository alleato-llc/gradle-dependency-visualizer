import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class ConflictTableViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "ConflictTable")
    private let fileExporter: any FileExporter

    let conflicts: [DependencyConflict]
    let projectName: String

    enum SortField: String {
        case coordinate
        case requestedVersion
        case resolvedVersion
        case requestedBy
    }

    var sortField: SortField = .coordinate
    var sortAscending = true

    var sortedConflicts: [DependencyConflict] {
        conflicts.sorted { a, b in
            let result: Bool
            switch sortField {
            case .coordinate:
                result = a.coordinate < b.coordinate
            case .requestedVersion:
                result = a.requestedVersion < b.requestedVersion
            case .resolvedVersion:
                result = a.resolvedVersion < b.resolvedVersion
            case .requestedBy:
                result = a.requestedBy < b.requestedBy
            }
            return sortAscending ? result : !result
        }
    }

    init(tree: DependencyTree, fileExporter: any FileExporter) {
        self.conflicts = tree.conflicts
        self.projectName = tree.projectName
        self.fileExporter = fileExporter
    }

    func toggleSort(field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }

    func exportConflictsAsJSON() {
        let entries = sortedConflicts.map { conflict in
            [
                "coordinate": conflict.coordinate,
                "requestedVersion": conflict.requestedVersion,
                "resolvedVersion": conflict.resolvedVersion,
                "requestedBy": conflict.requestedBy,
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        do {
            try fileExporter.saveData(data, defaultName: "\(projectName)-conflicts.json", contentType: .json)
            logger.info("Conflicts exported successfully")
        } catch {
            logger.error("Failed to export conflicts: \(error.localizedDescription)")
        }
    }
}
