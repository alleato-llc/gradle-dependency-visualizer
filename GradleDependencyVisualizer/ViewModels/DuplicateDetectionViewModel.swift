import Foundation
import os
import UniformTypeIdentifiers
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices

@Observable @MainActor
final class DuplicateDetectionViewModel {
    private let logger = Logger(subsystem: "com.alleato.gradledependencyvisualizer", category: "DuplicateDetection")
    private let fileExporter: any FileExporter

    private(set) var results: [DuplicateDependencyResult] = []
    let projectName: String
    private let tree: DependencyTree
    private let projectPath: String
    private let modules: [GradleModule]

    enum SortField: String {
        case coordinate
        case kind
        case moduleCount
        case recommendation
    }

    var sortField: SortField = .coordinate
    var sortAscending = true

    var sortedResults: [DuplicateDependencyResult] {
        results.sorted { a, b in
            let result: Bool
            switch sortField {
            case .coordinate:
                result = a.coordinate < b.coordinate
            case .kind:
                result = a.kind.rawValue < b.kind.rawValue
            case .moduleCount:
                result = a.modules.count < b.modules.count
            case .recommendation:
                result = a.recommendation < b.recommendation
            }
            return sortAscending ? result : !result
        }
    }

    init(
        tree: DependencyTree,
        fileExporter: any FileExporter,
        projectPath: String,
        modules: [GradleModule] = []
    ) {
        self.tree = tree
        self.projectName = tree.projectName
        self.fileExporter = fileExporter
        self.projectPath = projectPath
        self.modules = modules
    }

    func detect() {
        results = DuplicateDependencyCalculator.detect(
            tree: tree,
            projectPath: projectPath,
            modules: modules
        )
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
                "kind": result.kind.rawValue,
                "modules": result.modules.joined(separator: ", "),
                "hasVersionMismatch": result.hasVersionMismatch ? "true" : "false",
                "recommendation": result.recommendation,
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        do {
            try fileExporter.saveData(data, defaultName: "\(projectName)-duplicates.json", contentType: .json)
            logger.info("Duplicate detection exported successfully")
        } catch {
            logger.error("Failed to export duplicate detection: \(error.localizedDescription)")
        }
    }
}
