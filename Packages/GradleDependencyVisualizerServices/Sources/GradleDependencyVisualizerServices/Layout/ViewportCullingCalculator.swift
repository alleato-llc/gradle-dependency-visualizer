import CoreGraphics
import Foundation

public enum ViewportCullingCalculator {
    /// Returns IDs of nodes whose frames intersect the visible rect (with margin).
    /// `positions` contains the node positions where x/y is the **top-left** corner.
    /// `nodeSize` returns the size for a given subtree size.
    public static func visibleNodeIds(
        positions: [NodePosition],
        nodeSize: (Int) -> CGSize,
        visibleRect: CGRect,
        scale: CGFloat,
        margin: CGFloat = 300
    ) -> Set<String> {
        // Expand the visible rect by margin on all sides
        let expandedRect = visibleRect.insetBy(dx: -margin, dy: -margin)

        var result = Set<String>()
        for pos in positions {
            let size = nodeSize(pos.subtreeSize)
            // NodePosition x/y is the top-left corner; frame in scaled content coordinates
            let nodeFrame = CGRect(
                x: pos.x * scale,
                y: pos.y * scale,
                width: size.width * scale,
                height: size.height * scale
            )
            if expandedRect.intersects(nodeFrame) {
                result.insert(pos.nodeId)
            }
        }
        return result
    }
}
