import Foundation
import GradleDependencyVisualizerCore

public enum JsonTreeImporter {
    public static func importTree(from data: Data) throws -> DependencyTree {
        try JSONDecoder().decode(DependencyTree.self, from: data)
    }
}
