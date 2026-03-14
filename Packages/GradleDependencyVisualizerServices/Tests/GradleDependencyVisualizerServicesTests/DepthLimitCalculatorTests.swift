import Testing
@testable import GradleDependencyVisualizerServices

@Suite
struct DepthLimitCalculatorTests {
    @Test
    func recommendsDepth1ForVeryLargeTree() {
        // Simulate 10K nodes: 1 at depth 0, 10 at depth 1, 100 at depth 2, rest deeper
        var nodeDepths: [String: Int] = [:]
        nodeDepths["root"] = 0
        for i in 0..<10 {
            nodeDepths["d1-\(i)"] = 1
        }
        for i in 0..<100 {
            nodeDepths["d2-\(i)"] = 2
        }
        for i in 0..<9889 {
            nodeDepths["d3-\(i)"] = 3
        }

        let depth = DepthLimitCalculator.recommendedDepth(
            nodeDepths: nodeDepths,
            targetNodeCount: 500
        )

        #expect(depth >= 1)
        #expect(depth <= 2)
    }

    @Test
    func returnsMaxDepthWhenUnderThreshold() {
        var nodeDepths: [String: Int] = [:]
        nodeDepths["root"] = 0
        for i in 0..<10 {
            nodeDepths["d1-\(i)"] = 1
        }
        for i in 0..<20 {
            nodeDepths["d2-\(i)"] = 2
        }
        for i in 0..<30 {
            nodeDepths["d3-\(i)"] = 3
        }

        let depth = DepthLimitCalculator.recommendedDepth(
            nodeDepths: nodeDepths,
            targetNodeCount: 500
        )

        #expect(depth == 3)
    }

    @Test
    func handlesEmptyDepths() {
        let depth = DepthLimitCalculator.recommendedDepth(
            nodeDepths: [:],
            targetNodeCount: 500
        )

        #expect(depth == 0)
    }

    @Test
    func increasesDepthAsThresholdGrows() {
        var nodeDepths: [String: Int] = [:]
        nodeDepths["root"] = 0
        for i in 0..<50 {
            nodeDepths["d1-\(i)"] = 1
        }
        for i in 0..<200 {
            nodeDepths["d2-\(i)"] = 2
        }
        for i in 0..<1000 {
            nodeDepths["d3-\(i)"] = 3
        }

        let depthSmall = DepthLimitCalculator.recommendedDepth(
            nodeDepths: nodeDepths,
            targetNodeCount: 60
        )
        let depthLarge = DepthLimitCalculator.recommendedDepth(
            nodeDepths: nodeDepths,
            targetNodeCount: 500
        )

        #expect(depthLarge >= depthSmall)
    }
}
