import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class ScopeValidationViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "ScopeValidation")
    private let fileExporter: any FileExporter

    let results: [ScopeValidationResult]
    let projectName: String

    enum SortField: String {
        case coordinate
        case version
        case matchedLibrary
    }

    var sortField: SortField = .matchedLibrary
    var sortAscending = true

    var sortedResults: [ScopeValidationResult] {
        results.sorted { a, b in
            let result: Bool
            switch sortField {
            case .coordinate:
                result = a.coordinate < b.coordinate
            case .version:
                result = a.version < b.version
            case .matchedLibrary:
                result = a.matchedLibrary < b.matchedLibrary
            }
            return sortAscending ? result : !result
        }
    }

    init(tree: DependencyTree, fileExporter: any FileExporter) {
        self.results = DependencyScopeValidator.validate(tree: tree)
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

    func exportAsJSON() {
        let entries = sortedResults.map { result in
            [
                "coordinate": result.coordinate,
                "version": result.version,
                "matchedLibrary": result.matchedLibrary,
                "configuration": result.configuration.rawValue,
                "recommendation": result.recommendation,
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        do {
            try fileExporter.saveData(data, defaultName: "\(projectName)-scope-validation.json", contentType: .json)
            logger.info("Scope validation exported successfully")
        } catch {
            logger.error("Failed to export scope validation: \(error.localizedDescription)")
        }
    }
}
