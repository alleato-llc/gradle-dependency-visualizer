import Foundation
import GradleDependencyVisualizerCore

public enum DuplicateDependencyCalculator {
    public static func detectCrossModule(tree: DependencyTree) -> [DuplicateDependencyResult] {
        let moduleNodes = tree.roots.filter { $0.requestedVersion == "module" }
        guard moduleNodes.count >= 2 else { return [] }

        // Map: coordinate → [(moduleName, version)]
        var coordinateModules: [String: [(module: String, version: String)]] = [:]

        for moduleNode in moduleNodes {
            let moduleName = moduleNode.artifact
            for child in moduleNode.children {
                let coordinate = child.coordinate
                let version = child.resolvedVersion ?? child.requestedVersion
                coordinateModules[coordinate, default: []].append((module: moduleName, version: version))
            }
        }

        var results: [DuplicateDependencyResult] = []

        for (coordinate, entries) in coordinateModules where entries.count >= 2 {
            let modules = entries.map(\.module)
            var versions: [String: String] = [:]
            for entry in entries {
                versions[entry.module] = entry.version
            }
            let uniqueVersions = Set(entries.map(\.version))
            let hasMismatch = uniqueVersions.count > 1
            let recommendation = hasMismatch
                ? "Version mismatch — standardize"
                : "Consolidate to root project"

            results.append(DuplicateDependencyResult(
                coordinate: coordinate,
                kind: .crossModule,
                modules: modules,
                versions: versions,
                hasVersionMismatch: hasMismatch,
                recommendation: recommendation
            ))
        }

        return results.sorted { $0.coordinate < $1.coordinate }
    }

    public static func detectWithinModule(
        projectPath: String,
        modules: [GradleModule]
    ) -> [DuplicateDependencyResult] {
        let fileManager = FileManager.default
        var results: [DuplicateDependencyResult] = []

        let modulePaths: [(name: String, buildFilePath: String?)] = if modules.isEmpty {
            [("root", findBuildFile(at: projectPath, fileManager: fileManager))]
        } else {
            modules.map { module in
                let relativePath = String(module.path.dropFirst()).replacingOccurrences(of: ":", with: "/")
                let moduleDirPath = projectPath + "/" + relativePath
                return (module.name, findBuildFile(at: moduleDirPath, fileManager: fileManager))
            }
        }

        for (moduleName, buildFilePath) in modulePaths {
            guard let buildFilePath,
                  let content = try? String(contentsOfFile: buildFilePath, encoding: .utf8) else {
                continue
            }

            let declarations = GradleBuildFileParser.parseDependencies(from: content)

            // Group by coordinate
            var byCoordinate: [String: [GradleBuildFileParser.DependencyDeclaration]] = [:]
            for decl in declarations {
                let coordinate = "\(decl.group):\(decl.artifact)"
                byCoordinate[coordinate, default: []].append(decl)
            }

            for (coordinate, decls) in byCoordinate where decls.count >= 2 {
                var versions: [String: String] = [:]
                for decl in decls {
                    versions["\(decl.configuration) (line \(decl.line))"] = decl.version
                }

                results.append(DuplicateDependencyResult(
                    coordinate: coordinate,
                    kind: .withinModule,
                    modules: [moduleName],
                    versions: versions,
                    hasVersionMismatch: false,
                    recommendation: "Declared \(decls.count) times in \(moduleName) — remove duplicate declaration"
                ))
            }
        }

        return results.sorted { $0.coordinate < $1.coordinate }
    }

    public static func detect(
        tree: DependencyTree,
        projectPath: String,
        modules: [GradleModule]
    ) -> [DuplicateDependencyResult] {
        let crossModule = detectCrossModule(tree: tree)
        let withinModule = detectWithinModule(projectPath: projectPath, modules: modules)
        return (crossModule + withinModule).sorted { $0.coordinate < $1.coordinate }
    }

    private static func findBuildFile(at directoryPath: String, fileManager: FileManager) -> String? {
        let ktsPath = directoryPath + "/build.gradle.kts"
        if fileManager.fileExists(atPath: ktsPath) { return ktsPath }
        let groovyPath = directoryPath + "/build.gradle"
        if fileManager.fileExists(atPath: groovyPath) { return groovyPath }
        return nil
    }
}
