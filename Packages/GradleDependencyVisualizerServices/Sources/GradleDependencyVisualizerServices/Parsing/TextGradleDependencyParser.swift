import Foundation
import GradleDependencyVisualizerCore

public struct TextGradleDependencyParser: GradleDependencyParser {
    public init() {}

    public func parse(output: String, projectName: String, configuration: GradleConfiguration) -> DependencyTree {
        let lines = output.components(separatedBy: .newlines)
        var roots: [DependencyNode] = []
        var conflicts: [DependencyConflict] = []
        var stack: [(depth: Int, node: DependencyNode)] = []

        for line in lines {
            guard let parsed = parseLine(line) else { continue }

            let node = DependencyNode(
                group: parsed.group,
                artifact: parsed.artifact,
                requestedVersion: parsed.requestedVersion,
                resolvedVersion: parsed.resolvedVersion,
                isOmitted: parsed.isOmitted,
                isConstraint: parsed.isConstraint
            )

            if parsed.resolvedVersion != nil && parsed.resolvedVersion != parsed.requestedVersion {
                let parentCoordinate = stack.last?.node.coordinate ?? projectName
                conflicts.append(DependencyConflict(
                    coordinate: "\(parsed.group):\(parsed.artifact)",
                    requestedVersion: parsed.requestedVersion,
                    resolvedVersion: parsed.resolvedVersion!,
                    requestedBy: parentCoordinate
                ))
            }

            if parsed.depth == 0 {
                // Finalize any remaining stack items
                finalizeStack(&stack, roots: &roots)
                stack.append((depth: 0, node: node))
            } else {
                // Pop stack entries at same or deeper depth
                while let last = stack.last, last.depth >= parsed.depth {
                    let popped = stack.removeLast()
                    if let parent = stack.last {
                        let parentWithChild = appendChildToNode(parent: parent.node, child: popped.node)
                        stack[stack.count - 1] = (depth: parent.depth, node: parentWithChild)
                    } else {
                        roots.append(popped.node)
                    }
                }
                stack.append((depth: parsed.depth, node: node))
            }
        }

        finalizeStack(&stack, roots: &roots)

        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: roots,
            conflicts: conflicts
        )
    }

    private func finalizeStack(_ stack: inout [(depth: Int, node: DependencyNode)], roots: inout [DependencyNode]) {
        while let popped = stack.popLast() {
            if let parent = stack.last {
                let parentWithChild = appendChildToNode(parent: parent.node, child: popped.node)
                stack[stack.count - 1] = (depth: parent.depth, node: parentWithChild)
            } else {
                roots.append(popped.node)
            }
        }
    }

    private func appendChildToNode(parent: DependencyNode, child: DependencyNode) -> DependencyNode {
        DependencyNode(
            group: parent.group,
            artifact: parent.artifact,
            requestedVersion: parent.requestedVersion,
            resolvedVersion: parent.resolvedVersion,
            isOmitted: parent.isOmitted,
            isConstraint: parent.isConstraint,
            children: parent.children + [child]
        )
    }

    struct ParsedDependency {
        let depth: Int
        let group: String
        let artifact: String
        let requestedVersion: String
        let resolvedVersion: String?
        let isOmitted: Bool
        let isConstraint: Bool
    }

    func parseLine(_ line: String) -> ParsedDependency? {
        // Match lines with tree prefixes like "+--- ", "\--- ", "|    +--- "
        // The depth is determined by how many segments of "|    " or "     " prefix exist
        let treePattern = #"^([\| ]{0,})[+\\]--- (.+)$"#
        guard let match = line.range(of: treePattern, options: .regularExpression) else {
            return nil
        }

        let matched = String(line[match])

        // Find the position of +--- or \---
        guard let markerRange = matched.range(of: #"[+\\]---"#, options: .regularExpression) else {
            return nil
        }

        let prefixLength = matched.distance(from: matched.startIndex, to: markerRange.lowerBound)
        let depth = prefixLength / 5 // Each level is "|    " = 5 chars

        // Extract the dependency string after "+--- " or "\--- "
        let depStart = matched.index(markerRange.upperBound, offsetBy: 1)
        var depString = String(matched[depStart...]).trimmingCharacters(in: .whitespaces)

        // Check for markers
        let isOmitted = depString.contains("(*)")
        let isConstraint = depString.contains("(c)")

        // Remove markers
        depString = depString
            .replacingOccurrences(of: "(*)", with: "")
            .replacingOccurrences(of: "(c)", with: "")
            .replacingOccurrences(of: "(n)", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Check for conflict: "group:artifact:requested -> resolved"
        var resolvedVersion: String?
        if let arrowRange = depString.range(of: " -> ") {
            resolvedVersion = String(depString[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            depString = String(depString[..<arrowRange.lowerBound])
        }

        // Parse group:artifact:version or group:artifact (when version comes via ->)
        let parts = depString.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        let requestedVersion: String
        if parts.count >= 3 {
            requestedVersion = parts[2]
        } else if let resolved = resolvedVersion {
            // group:artifact -> version (no explicit requested version, e.g. BOM-managed)
            requestedVersion = resolved
            resolvedVersion = nil
        } else {
            return nil
        }

        return ParsedDependency(
            depth: depth,
            group: parts[0],
            artifact: parts[1],
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            isOmitted: isOmitted,
            isConstraint: isConstraint
        )
    }
}
