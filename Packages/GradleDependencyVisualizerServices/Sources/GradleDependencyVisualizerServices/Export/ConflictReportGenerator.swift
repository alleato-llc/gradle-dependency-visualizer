import Foundation
import GradleDependencyVisualizerCore

@available(*, deprecated, renamed: "ReportFormat")
public typealias ConflictReportFormat = ReportFormat

public enum ConflictReportGenerator {
    public static func report(tree: DependencyTree, format: ReportFormat) -> String {
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
                var line = "    \(conflict.requestedVersion) -> \(conflict.resolvedVersion) (requested by \(conflict.requestedBy))"
                if let riskLevel = conflict.riskLevel {
                    line += " [\(riskLevel.rawValue)]"
                }
                lines.append(line)
                if let riskReason = conflict.riskReason {
                    lines.append("    risk: \(riskReason)")
                }
            }
            lines.append("")
        }

        lines.append("Total: \(tree.conflicts.count) conflict(s) across \(grouped.count) dependency(ies)")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(tree: DependencyTree) -> String {
        let conflicts = tree.conflicts.map { conflict -> [String: Any] in
            var entry: [String: Any] = [
                "coordinate": conflict.coordinate,
                "requestedVersion": conflict.requestedVersion,
                "resolvedVersion": conflict.resolvedVersion,
                "requestedBy": conflict.requestedBy,
            ]
            if let riskLevel = conflict.riskLevel {
                entry["riskLevel"] = riskLevel.rawValue
            }
            if let riskReason = conflict.riskReason {
                entry["riskReason"] = riskReason
            }
            return entry
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
