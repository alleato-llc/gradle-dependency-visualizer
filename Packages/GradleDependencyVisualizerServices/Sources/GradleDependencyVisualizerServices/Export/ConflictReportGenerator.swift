import Foundation
import GradleDependencyVisualizerCore

public enum ConflictReportFormat: String, Sendable {
    case text
    case json
}

public enum ConflictReportGenerator {
    public static func report(tree: DependencyTree, format: ConflictReportFormat) -> String {
        switch format {
        case .text:
            textReport(tree: tree)
        case .json:
            jsonReport(tree: tree)
        }
    }

    private static func textReport(tree: DependencyTree) -> String {
        if tree.conflicts.isEmpty {
            return "No dependency conflicts found in \(tree.projectName) (\(tree.configuration.displayName))."
        }

        var lines: [String] = []
        lines.append("Dependency Conflicts in \(tree.projectName) (\(tree.configuration.displayName))")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        let grouped = Dictionary(grouping: tree.conflicts, by: \.coordinate)
        for (coordinate, conflicts) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(coordinate)")
            for conflict in conflicts {
                lines.append("    \(conflict.requestedVersion) -> \(conflict.resolvedVersion) (requested by \(conflict.requestedBy))")
            }
            lines.append("")
        }

        lines.append("Total: \(tree.conflicts.count) conflict(s) across \(grouped.count) dependency(ies)")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(tree: DependencyTree) -> String {
        let conflicts = tree.conflicts.map { conflict in
            [
                "coordinate": conflict.coordinate,
                "requestedVersion": conflict.requestedVersion,
                "resolvedVersion": conflict.resolvedVersion,
                "requestedBy": conflict.requestedBy,
            ]
        }

        let report: [String: Any] = [
            "projectName": tree.projectName,
            "configuration": tree.configuration.rawValue,
            "conflictCount": tree.conflicts.count,
            "conflicts": conflicts,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
