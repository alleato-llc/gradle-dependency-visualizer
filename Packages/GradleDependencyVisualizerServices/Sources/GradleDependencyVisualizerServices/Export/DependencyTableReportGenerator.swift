import Foundation
import GradleDependencyVisualizerCore

public enum DependencyTableReportGenerator {
    public static func report(
        entries: [FlatDependencyEntry],
        tree: DependencyTree,
        format: ReportFormat
    ) -> String {
        switch format {
        case .text:
            textReport(entries: entries, tree: tree)
        case .json:
            jsonReport(entries: entries, tree: tree)
        }
    }

    private static func textReport(entries: [FlatDependencyEntry], tree: DependencyTree) -> String {
        if entries.isEmpty {
            return "No dependencies found in \(tree.projectName) (\(tree.configuration.displayName))."
        }

        var lines: [String] = []
        lines.append("Dependencies in \(tree.projectName) (\(tree.configuration.displayName))")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        for entry in entries {
            let conflict = entry.hasConflict ? " [CONFLICT]" : ""
            let versions = entry.versions.count > 1
                ? " (versions: \(entry.versions.sorted().joined(separator: ", ")))"
                : ""
            lines.append("  \(entry.coordinate):\(entry.version)\(conflict)\(versions)")
            if !entry.usedBy.isEmpty {
                lines.append("    used by: \(entry.usedBy.joined(separator: ", "))")
            }
        }

        lines.append("")
        lines.append("Total: \(entries.count) unique dependency(ies)")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(entries: [FlatDependencyEntry], tree: DependencyTree) -> String {
        let jsonEntries = entries.map { entry -> [String: Any] in
            [
                "coordinate": entry.coordinate,
                "group": entry.group,
                "artifact": entry.artifact,
                "version": entry.version,
                "hasConflict": entry.hasConflict,
                "occurrenceCount": entry.occurrenceCount,
                "usedBy": entry.usedBy,
                "versions": Array(entry.versions.sorted()),
            ] as [String: Any]
        }

        let report: [String: Any] = [
            "projectName": tree.projectName,
            "configuration": tree.configuration.rawValue,
            "dependencyCount": entries.count,
            "dependencies": jsonEntries,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
