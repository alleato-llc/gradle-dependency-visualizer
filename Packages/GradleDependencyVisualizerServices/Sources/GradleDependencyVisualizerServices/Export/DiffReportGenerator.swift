import Foundation
import GradleDependencyVisualizerCore

public enum DiffReportGenerator {
    public static func report(
        entries: [DependencyDiffEntry],
        result: DependencyDiffResult,
        format: ReportFormat
    ) -> String {
        switch format {
        case .text:
            textReport(entries: entries, result: result)
        case .json:
            jsonReport(entries: entries, result: result)
        }
    }

    private static func textReport(entries: [DependencyDiffEntry], result: DependencyDiffResult) -> String {
        if entries.isEmpty {
            return "No differences found between \(result.baselineName) and \(result.currentName)."
        }

        var lines: [String] = []
        lines.append("Dependency Diff: \(result.baselineName) → \(result.currentName)")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        let summary = [
            result.added.count > 0 ? "\(result.added.count) added" : nil,
            result.removed.count > 0 ? "\(result.removed.count) removed" : nil,
            result.versionChanged.count > 0 ? "\(result.versionChanged.count) changed" : nil,
            result.unchanged.count > 0 ? "\(result.unchanged.count) unchanged" : nil,
        ].compactMap { $0 }
        lines.append("Summary: \(summary.joined(separator: ", "))")
        lines.append("")

        for entry in entries.sorted(by: { $0.coordinate < $1.coordinate }) {
            let before = entry.effectiveBeforeVersion ?? "-"
            let after = entry.effectiveAfterVersion ?? "-"

            switch entry.changeKind {
            case .added:
                lines.append("  + \(entry.coordinate):\(after)")
            case .removed:
                lines.append("  - \(entry.coordinate):\(before)")
            case .versionChanged:
                lines.append("  ~ \(entry.coordinate): \(before) → \(after)")
            case .unchanged:
                lines.append("  = \(entry.coordinate):\(before)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func jsonReport(entries: [DependencyDiffEntry], result: DependencyDiffResult) -> String {
        let jsonEntries = entries.sorted(by: { $0.coordinate < $1.coordinate }).map { entry -> [String: Any] in
            var dict: [String: Any] = [
                "coordinate": entry.coordinate,
                "changeKind": entry.changeKind.rawValue,
            ]
            if let before = entry.effectiveBeforeVersion { dict["beforeVersion"] = before }
            if let after = entry.effectiveAfterVersion { dict["afterVersion"] = after }
            return dict
        }

        let report: [String: Any] = [
            "baseline": result.baselineName,
            "current": result.currentName,
            "added": result.added.count,
            "removed": result.removed.count,
            "changed": result.versionChanged.count,
            "unchanged": result.unchanged.count,
            "entries": jsonEntries,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
