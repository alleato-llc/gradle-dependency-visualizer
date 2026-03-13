import Foundation
import GradleDependencyVisualizerCore

public enum TreeImporter {
    /// Imports a dependency tree from file data, auto-detecting the format.
    /// Tries JSON first; if that fails, parses as Gradle text output.
    public static func importTree(
        from data: Data,
        fileName: String,
        fallbackConfiguration: GradleConfiguration = .compileClasspath
    ) throws -> DependencyTree {
        // Try JSON first
        if let tree = try? JsonTreeImporter.importTree(from: data) {
            return tree
        }

        // Fall back to Gradle text output
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw TreeImportError.unreadableFile
        }

        let parser = TextGradleDependencyParser()
        let projectName = Self.projectName(from: fileName)
        let tree = parser.parse(output: text, projectName: projectName, configuration: fallbackConfiguration)

        guard tree.totalNodeCount > 0 else {
            throw TreeImportError.noDependenciesFound
        }

        return tree
    }

    private static func projectName(from fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        // Strip common suffixes like "-dependencies", "-compileClasspath"
        for suffix in ["-dependencies", "-compileClasspath", "-runtimeClasspath"] {
            if name.hasSuffix(suffix) {
                return String(name.dropLast(suffix.count))
            }
        }
        return name
    }
}

public enum TreeImportError: Error, LocalizedError {
    case unreadableFile
    case noDependenciesFound

    public var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "The file could not be read as text or JSON."
        case .noDependenciesFound:
            "No dependencies were found in the file. Expected JSON or Gradle dependency tree output."
        }
    }
}
