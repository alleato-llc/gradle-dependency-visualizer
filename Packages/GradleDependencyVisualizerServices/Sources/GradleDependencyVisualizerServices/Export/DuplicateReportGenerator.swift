import Foundation
import GradleDependencyVisualizerCore

public enum DuplicateReportGenerator {
    public static func report(
        results: [DuplicateDependencyResult],
        tree: DependencyTree,
        format: ReportFormat
    ) -> String {
        switch format {
        case .text:
            textReport(results: results, tree: tree)
        case .json:
            jsonReport(results: results, tree: tree)
        }
    }

    private static func textReport(results: [DuplicateDependencyResult], tree: DependencyTree) -> String {
        if results.isEmpty {
            return "No duplicate dependencies found in \(tree.projectName) (\(tree.configuration.displayName))."
        }

        var lines: [String] = []
        lines.append("Duplicate Dependencies in \(tree.projectName) (\(tree.configuration.displayName))")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        let crossModule = results.filter { $0.kind == .crossModule }
        let withinModule = results.filter { $0.kind == .withinModule }

        if !crossModule.isEmpty {
            lines.append("Cross-module duplicates:")
            lines.append("")
            for result in crossModule {
                let mismatch = result.hasVersionMismatch ? " [VERSION MISMATCH]" : ""
                lines.append("  \(result.coordinate)\(mismatch)")
                lines.append("    modules: \(result.modules.joined(separator: ", "))")
                for (module, version) in result.versions.sorted(by: { $0.key < $1.key }) {
                    lines.append("    \(module): \(version)")
                }
                lines.append("    recommendation: \(result.recommendation)")
                lines.append("")
            }
        }

        if !withinModule.isEmpty {
            lines.append("Within-module duplicates:")
            lines.append("")
            for result in withinModule {
                lines.append("  \(result.coordinate)")
                lines.append("    \(result.recommendation)")
                lines.append("")
            }
        }

        lines.append("Total: \(results.count) duplicate(s) (\(crossModule.count) cross-module, \(withinModule.count) within-module)")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(results: [DuplicateDependencyResult], tree: DependencyTree) -> String {
        let jsonResults = results.map { result -> [String: Any] in
            [
                "coordinate": result.coordinate,
                "kind": result.kind.rawValue,
                "modules": result.modules,
                "versions": result.versions,
                "hasVersionMismatch": result.hasVersionMismatch,
                "recommendation": result.recommendation,
            ] as [String: Any]
        }

        let report: [String: Any] = [
            "projectName": tree.projectName,
            "configuration": tree.configuration.rawValue,
            "duplicateCount": results.count,
            "duplicates": jsonResults,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
