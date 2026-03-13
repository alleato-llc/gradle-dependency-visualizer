import GradleDependencyVisualizerCore

public enum DependencyTableCalculator {
    public static func flatEntries(from tree: DependencyTree) -> [FlatDependencyEntry] {
        let parents = parentMap(from: tree)
        let allNodes = DependencyAnalysisCalculator.allNodes(from: tree)
        let conflictCoordinates = Set(tree.conflicts.map(\.coordinate))

        var grouped: [String: [DependencyNode]] = [:]
        for node in allNodes {
            grouped[node.coordinate, default: []].append(node)
        }

        return grouped.map { coordinate, nodes in
            let preferredNode = nodes.first(where: { !$0.isOmitted }) ?? nodes[0]
            let version = preferredNode.resolvedVersion ?? preferredNode.requestedVersion
            let allVersions = Set(nodes.flatMap { node in
                var v = [node.requestedVersion]
                if let resolved = node.resolvedVersion {
                    v.append(resolved)
                }
                return v
            })
            let hasConflict = conflictCoordinates.contains(coordinate) || nodes.contains(where: \.hasConflict)
            let isOmitted = nodes.allSatisfy(\.isOmitted)
            let usedBy = (parents[coordinate] ?? []).sorted()

            return FlatDependencyEntry(
                group: preferredNode.group,
                artifact: preferredNode.artifact,
                coordinate: coordinate,
                version: version,
                hasConflict: hasConflict,
                isOmitted: isOmitted,
                occurrenceCount: nodes.count,
                usedBy: usedBy,
                versions: allVersions
            )
        }
        .sorted { $0.coordinate < $1.coordinate }
    }

    public static func parentMap(from tree: DependencyTree) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for root in tree.roots {
            buildParentMap(node: root, parent: nil, result: &result)
        }
        return result
    }

    private static func buildParentMap(node: DependencyNode, parent: DependencyNode?, result: inout [String: Set<String>]) {
        if let parent {
            result[node.coordinate, default: []].insert(parent.coordinate)
        }
        for child in node.children {
            buildParentMap(node: child, parent: node, result: &result)
        }
    }
}
