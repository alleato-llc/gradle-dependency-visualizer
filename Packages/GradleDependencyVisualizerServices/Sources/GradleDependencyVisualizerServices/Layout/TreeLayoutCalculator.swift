import Foundation
import GradleDependencyVisualizerCore

public struct NodePosition: Sendable {
    public let nodeId: String
    public let x: Double
    public let y: Double
    public let subtreeSize: Int

    public init(nodeId: String, x: Double, y: Double, subtreeSize: Int) {
        self.nodeId = nodeId
        self.x = x
        self.y = y
        self.subtreeSize = subtreeSize
    }
}

public enum TreeLayoutCalculator {
    private static let horizontalSpacing: Double = 160
    private static let verticalSpacing: Double = 120
    private static let siblingGap: Double = 30
    private static let fixedNodeWidth: Double = 160
    private static let fixedNodeHeight: Double = 60

    public static func layout(tree: DependencyTree) -> [NodePosition] {
        var positions: [NodePosition] = []
        var positionIndex: [String: NodePosition] = [:]
        var xOffset: Double = 0

        for root in tree.roots {
            let width = layoutNode(root, depth: 0, xStart: xOffset, positions: &positions, positionIndex: &positionIndex)
            xOffset += width + horizontalSpacing
        }

        // Normalize positions so nothing is at negative x/y
        let minX = positions.map(\.x).min() ?? 0
        let minY = positions.map(\.y).min() ?? 0
        if minX < 0 || minY < 0 {
            positions = positions.map { pos in
                NodePosition(
                    nodeId: pos.nodeId,
                    x: pos.x - min(minX, 0),
                    y: pos.y - min(minY, 0),
                    subtreeSize: pos.subtreeSize
                )
            }
        }

        return positions
    }

    public static func nodeWidth(for subtreeSize: Int) -> Double {
        fixedNodeWidth
    }

    public static func nodeHeight(for subtreeSize: Int) -> Double {
        fixedNodeHeight
    }

    /// Returns true for leaf nodes that are omitted duplicates or BOM constraints.
    /// These don't add unique information to the graph — the real dependency is
    /// shown elsewhere in the tree.
    private static func shouldExcludeFromLayout(_ node: DependencyNode) -> Bool {
        node.children.isEmpty && (node.isOmitted || node.isConstraint)
    }

    @discardableResult
    private static func layoutNode(
        _ node: DependencyNode,
        depth: Int,
        xStart: Double,
        positions: inout [NodePosition],
        positionIndex: inout [String: NodePosition]
    ) -> Double {
        let y = Double(depth) * verticalSpacing
        let myWidth = fixedNodeWidth

        if node.children.isEmpty {
            let position = NodePosition(
                nodeId: node.id,
                x: xStart,
                y: y,
                subtreeSize: node.subtreeSize
            )
            positions.append(position)
            positionIndex[node.id] = position
            return myWidth
        }

        // Only layout children that contribute unique information
        let visibleChildren = node.children.filter { !shouldExcludeFromLayout($0) }

        if visibleChildren.isEmpty {
            // All children are omitted/constraint — treat this node as a leaf
            let position = NodePosition(
                nodeId: node.id,
                x: xStart,
                y: y,
                subtreeSize: node.subtreeSize
            )
            positions.append(position)
            positionIndex[node.id] = position
            return myWidth
        }

        var childXOffset = xStart
        var childCenterXs: [Double] = []

        for (index, child) in visibleChildren.enumerated() {
            let childWidth = layoutNode(child, depth: depth + 1, xStart: childXOffset, positions: &positions, positionIndex: &positionIndex)

            if let lastChildPos = positionIndex[child.id] {
                let childNodeWidth = fixedNodeWidth
                childCenterXs.append(lastChildPos.x + childNodeWidth / 2)
            }

            childXOffset += childWidth + (index < visibleChildren.count - 1 ? siblingGap : 0)
        }

        let totalChildrenWidth = childXOffset - xStart

        // Center parent over children's center positions
        let centerX: Double
        if let firstCenter = childCenterXs.first, let lastCenter = childCenterXs.last {
            centerX = (firstCenter + lastCenter) / 2 - myWidth / 2
        } else {
            centerX = xStart
        }

        let position = NodePosition(
            nodeId: node.id,
            x: centerX,
            y: y,
            subtreeSize: node.subtreeSize
        )
        positions.append(position)
        positionIndex[node.id] = position

        return max(totalChildrenWidth, myWidth)
    }
}
