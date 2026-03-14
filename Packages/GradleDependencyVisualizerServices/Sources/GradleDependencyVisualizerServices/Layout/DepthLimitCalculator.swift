import Foundation

public enum DepthLimitCalculator {
    /// Returns the maximum depth where cumulative node count stays under `targetNodeCount`.
    /// Iterates depths 1, 2, 3... counting cumulative nodes at each level.
    /// Returns the highest depth where the count stays under the target.
    public static func recommendedDepth(
        nodeDepths: [String: Int],
        targetNodeCount: Int
    ) -> Int {
        guard !nodeDepths.isEmpty, targetNodeCount > 0 else { return 0 }

        let maxDepth = nodeDepths.values.max() ?? 0
        guard maxDepth > 0 else { return 0 }

        var cumulativeCount = 0
        var bestDepth = 0

        for depth in 0...maxDepth {
            let nodesAtDepth = nodeDepths.values.filter { $0 == depth }.count
            cumulativeCount += nodesAtDepth

            if cumulativeCount <= targetNodeCount {
                bestDepth = depth
            } else {
                break
            }
        }

        return max(bestDepth, 1)
    }
}
