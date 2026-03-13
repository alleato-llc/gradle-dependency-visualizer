import GradleDependencyVisualizerCore

public enum DependencyDiffCalculator {
    private struct NodeSummary {
        let requestedVersion: String
        let resolvedVersion: String?
        let isOmitted: Bool
        let isConstraint: Bool

        var effectiveVersion: String {
            resolvedVersion ?? requestedVersion
        }
    }

    public static func diff(baseline: DependencyTree, current: DependencyTree) -> DependencyDiffResult {
        let baselineMap = buildSummaryMap(from: baseline)
        let currentMap = buildSummaryMap(from: current)

        let allCoordinates = Set(baselineMap.keys).union(currentMap.keys)

        let entries: [DependencyDiffEntry] = allCoordinates.map { coordinate in
            let before = baselineMap[coordinate]
            let after = currentMap[coordinate]

            let changeKind: DependencyDiffEntry.ChangeKind
            if before == nil {
                changeKind = .added
            } else if after == nil {
                changeKind = .removed
            } else if before!.effectiveVersion != after!.effectiveVersion {
                changeKind = .versionChanged
            } else {
                changeKind = .unchanged
            }

            return DependencyDiffEntry(
                coordinate: coordinate,
                changeKind: changeKind,
                beforeVersion: before?.requestedVersion,
                afterVersion: after?.requestedVersion,
                beforeResolvedVersion: before?.resolvedVersion,
                afterResolvedVersion: after?.resolvedVersion
            )
        }.sorted { $0.coordinate < $1.coordinate }

        return DependencyDiffResult(
            baselineName: baseline.projectName,
            currentName: current.projectName,
            entries: entries
        )
    }

    private static func buildSummaryMap(from tree: DependencyTree) -> [String: NodeSummary] {
        let allNodes = DependencyAnalysisCalculator.allNodes(from: tree)
        var map: [String: NodeSummary] = [:]

        for node in allNodes {
            let summary = NodeSummary(
                requestedVersion: node.requestedVersion,
                resolvedVersion: node.resolvedVersion,
                isOmitted: node.isOmitted,
                isConstraint: node.isConstraint
            )

            if let existing = map[node.coordinate] {
                // Prefer non-omitted, non-constraint nodes
                if existing.isOmitted && !summary.isOmitted {
                    map[node.coordinate] = summary
                } else if existing.isConstraint && !summary.isConstraint && !summary.isOmitted {
                    map[node.coordinate] = summary
                }
            } else {
                map[node.coordinate] = summary
            }
        }

        return map
    }
}
