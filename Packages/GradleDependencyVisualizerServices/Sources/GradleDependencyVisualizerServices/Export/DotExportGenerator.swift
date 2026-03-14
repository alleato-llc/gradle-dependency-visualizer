import GradleDependencyVisualizerCore

public enum DotExportGenerator {
    public static func export(tree: DependencyTree) -> String {
        var lines: [String] = []
        lines.append("digraph dependencies {")
        lines.append("    rankdir=TB;")
        lines.append("    node [shape=box, style=filled, fontname=\"Helvetica\"];")
        lines.append("")

        var visited: Set<String> = []
        for root in tree.roots {
            exportNode(root, parentId: nil, lines: &lines, visited: &visited)
        }

        // Highlight conflicts
        for conflict in tree.conflicts {
            let nodeId = sanitizeId(conflict.coordinate)
            lines.append("    \(nodeId) [fillcolor=\"#ffcccc\"];")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func exportNode(
        _ node: DependencyNode,
        parentId: String?,
        lines: inout [String],
        visited: inout Set<String>
    ) {
        let nodeId = sanitizeId(node.coordinate)
        let label = "\(node.coordinate)\\n\(node.displayVersion)"

        if !visited.contains(node.coordinate) {
            visited.insert(node.coordinate)
            let fillColor = node.hasConflict ? "#ffcccc" : "#e8f4e8"
            lines.append("    \(nodeId) [label=\"\(label)\", fillcolor=\"\(fillColor)\"];")
        }

        if let parentId {
            lines.append("    \(parentId) -> \(nodeId);")
        }

        guard !node.isOmitted else { return }

        for child in node.children {
            exportNode(child, parentId: nodeId, lines: &lines, visited: &visited)
        }
    }

    private static func sanitizeId(_ coordinate: String) -> String {
        "\"" + coordinate.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
