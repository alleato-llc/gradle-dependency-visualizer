import Foundation
import GradleDependencyVisualizerCore

public enum ScopeValidationReportGenerator {
    public static func report(
        results: [ScopeValidationResult],
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

    private static func textReport(results: [ScopeValidationResult], tree: DependencyTree) -> String {
        if results.isEmpty {
            return "No scope issues found in \(tree.projectName) (\(tree.configuration.displayName))."
        }

        var lines: [String] = []
        lines.append("Scope Validation Issues in \(tree.projectName) (\(tree.configuration.displayName))")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        for result in results {
            lines.append("  \(result.coordinate):\(result.version)")
            lines.append("    detected as: \(result.matchedLibrary)")
            lines.append("    recommendation: \(result.recommendation)")
            lines.append("")
        }

        lines.append("Total: \(results.count) issue(s)")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(results: [ScopeValidationResult], tree: DependencyTree) -> String {
        let jsonResults = results.map { result in
            [
                "coordinate": result.coordinate,
                "version": result.version,
                "matchedLibrary": result.matchedLibrary,
                "configuration": result.configuration.rawValue,
                "recommendation": result.recommendation,
            ]
        }

        let report: [String: Any] = [
            "projectName": tree.projectName,
            "configuration": tree.configuration.rawValue,
            "issueCount": results.count,
            "issues": jsonResults,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
