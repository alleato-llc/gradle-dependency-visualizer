import Testing
import CoreGraphics
@testable import GradleDependencyVisualizerServices

@Suite
struct ViewportCullingCalculatorTests {
    private let defaultNodeSize: (Int) -> CGSize = { _ in CGSize(width: 160, height: 60) }

    @Test
    func nodeFullyInsideIsVisible() {
        let positions = [
            NodePosition(nodeId: "a", x: 100, y: 100, subtreeSize: 1)
        ]
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visible = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 0
        )

        #expect(visible.contains("a"))
    }

    @Test
    func nodeFullyOutsideIsHidden() {
        let positions = [
            NodePosition(nodeId: "a", x: 2000, y: 2000, subtreeSize: 1)
        ]
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visible = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 0
        )

        #expect(!visible.contains("a"))
    }

    @Test
    func nodePartiallyOverlappingIsVisible() {
        // Node at x=490, width=160 overlaps with a 500-wide rect
        let positions = [
            NodePosition(nodeId: "a", x: 490, y: 100, subtreeSize: 1)
        ]
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visible = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 0
        )

        #expect(visible.contains("a"))
    }

    @Test
    func marginExpandsVisibleArea() {
        // Node at x=600 is outside 500-wide rect, but within 300pt margin
        let positions = [
            NodePosition(nodeId: "a", x: 600, y: 100, subtreeSize: 1)
        ]
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visibleWithMargin = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 300
        )

        let visibleWithoutMargin = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 0
        )

        #expect(visibleWithMargin.contains("a"))
        #expect(!visibleWithoutMargin.contains("a"))
    }

    @Test
    func emptyPositionsReturnsEmptySet() {
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visible = ViewportCullingCalculator.visibleNodeIds(
            positions: [],
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0
        )

        #expect(visible.isEmpty)
    }

    @Test
    func scaleAffectsFrameCalculation() {
        // At scale 1.0, node at x=400 is inside 500-wide rect
        // At scale 2.0, node frame starts at x=800 which is outside
        let positions = [
            NodePosition(nodeId: "a", x: 400, y: 100, subtreeSize: 1)
        ]
        let visibleRect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let visibleAt1x = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 1.0,
            margin: 0
        )

        let visibleAt2x = ViewportCullingCalculator.visibleNodeIds(
            positions: positions,
            nodeSize: defaultNodeSize,
            visibleRect: visibleRect,
            scale: 2.0,
            margin: 0
        )

        #expect(visibleAt1x.contains("a"))
        #expect(!visibleAt2x.contains("a"))
    }
}
