import Foundation
import GradleDependencyVisualizerCore

public enum JsonTreeExporter {
    public static func export(tree: DependencyTree) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(tree)
    }
}
