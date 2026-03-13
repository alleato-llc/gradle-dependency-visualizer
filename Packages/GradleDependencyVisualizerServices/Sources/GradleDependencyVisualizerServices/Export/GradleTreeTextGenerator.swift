import GradleDependencyVisualizerCore

public enum GradleTreeTextGenerator {
    public static func export(tree: DependencyTree) -> String {
        var lines: [String] = []
        for (index, root) in tree.roots.enumerated() {
            let isLast = index == tree.roots.count - 1
            renderNode(root, prefix: "", isLast: isLast, lines: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private static func renderNode(
        _ node: DependencyNode,
        prefix: String,
        isLast: Bool,
        lines: inout [String]
    ) {
        let connector = isLast ? "\\--- " : "+--- "
        var dep = "\(node.group):\(node.artifact):\(node.requestedVersion)"

        if let resolved = node.resolvedVersion {
            dep = "\(node.group):\(node.artifact):\(node.requestedVersion) -> \(resolved)"
        }

        if node.isOmitted {
            dep += " (*)"
        }
        if node.isConstraint {
            dep += " (c)"
        }

        lines.append("\(prefix)\(connector)\(dep)")

        let childPrefix = prefix + (isLast ? "     " : "|    ")
        for (childIndex, child) in node.children.enumerated() {
            let childIsLast = childIndex == node.children.count - 1
            renderNode(child, prefix: childPrefix, isLast: childIsLast, lines: &lines)
        }
    }
}
