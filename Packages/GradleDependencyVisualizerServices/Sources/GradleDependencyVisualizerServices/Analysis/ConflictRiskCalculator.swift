import GradleDependencyVisualizerCore

public enum ConflictRiskCalculator {
    public static func assessConflicts(
        tree: DependencyTree,
        runner: any GradleRunner,
        projectPath: String
    ) async -> [DependencyConflict] {
        let bomCoordinates = await collectBOMCoordinates(
            conflicts: tree.conflicts,
            tree: tree,
            runner: runner,
            projectPath: projectPath
        )

        return tree.conflicts.map { conflict in
            assess(conflict: conflict, tree: tree, bomCoordinates: bomCoordinates)
        }
    }

    // MARK: - BOM Detection

    private static func collectBOMCoordinates(
        conflicts: [DependencyConflict],
        tree: DependencyTree,
        runner: any GradleRunner,
        projectPath: String
    ) async -> Set<String> {
        let uniqueCoordinates = Set(conflicts.map(\.coordinate))
        var bomManaged = Set<String>()

        // Fallback: tree-based constraint detection
        let treeConstraints = collectConstraintsFromTree(from: tree.roots)

        for coordinate in uniqueCoordinates {
            if let output = try? await runner.runDependencyInsight(
                projectPath: projectPath,
                dependency: coordinate,
                configuration: tree.configuration
            ), !output.isEmpty {
                let firstLine = output.prefix(while: { $0 != "\n" })
                if firstLine.contains("(selected by rule)") || firstLine.contains("(by constraint)") {
                    bomManaged.insert(coordinate)
                }
            } else {
                // Fallback to tree-based heuristic
                if treeConstraints[coordinate] != nil {
                    bomManaged.insert(coordinate)
                }
            }
        }

        return bomManaged
    }

    private static func assess(
        conflict: DependencyConflict,
        tree: DependencyTree,
        bomCoordinates: Set<String>
    ) -> DependencyConflict {
        let requested = parseVersion(conflict.requestedVersion)
        let resolved = parseVersion(conflict.resolvedVersion)

        let baseRisk: RiskLevel
        let baseReason: String

        if requested == nil || resolved == nil {
            baseRisk = .medium
            baseReason = "Unable to parse version"
        } else {
            let req = requested!
            let res = resolved!
            if req.major != res.major {
                baseRisk = .high
                baseReason = "Major version jump (\(req.major).x -> \(res.major).x)"
            } else if req.minor != res.minor {
                baseRisk = .medium
                baseReason = "Minor version jump (\(req.major).\(req.minor) -> \(res.major).\(res.minor))"
            } else if req.patch != res.patch {
                baseRisk = .low
                baseReason = "Patch version bump (\(req.major).\(req.minor).\(req.patch) -> \(res.major).\(res.minor).\(res.patch))"
            } else {
                baseRisk = .info
                baseReason = "Qualifier change only"
            }
        }

        var riskIndex = RiskLevel.allCases.firstIndex(of: baseRisk)!
        var adjustments: [String] = []

        // BOM-managed: detected via dependencyInsight or tree constraint fallback
        if bomCoordinates.contains(conflict.coordinate) {
            riskIndex = max(0, riskIndex - 1)
            adjustments.append("reduced: BOM-managed")
        }

        // Downgrade: resolved < requested
        if let req = parseVersion(conflict.requestedVersion),
           let res = parseVersion(conflict.resolvedVersion),
           res < req {
            riskIndex = min(RiskLevel.allCases.count - 1, riskIndex + 1)
            adjustments.append("downgrade detected")
        }

        // Test scope
        if !tree.configuration.isProduction {
            riskIndex = max(0, riskIndex - 1)
            adjustments.append("reduced: test scope")
        }

        let finalRisk = RiskLevel.allCases[riskIndex]
        var reason = baseReason
        if !adjustments.isEmpty {
            reason += ", " + adjustments.joined(separator: ", ")
        }

        return DependencyConflict(
            coordinate: conflict.coordinate,
            requestedVersion: conflict.requestedVersion,
            resolvedVersion: conflict.resolvedVersion,
            requestedBy: conflict.requestedBy,
            riskLevel: finalRisk,
            riskReason: reason
        )
    }

    // MARK: - Constraint Collection (Tree Fallback)

    private static func collectConstraintsFromTree(from nodes: [DependencyNode]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        collectConstraintsRecursive(nodes: nodes, into: &result)
        return result
    }

    private static func collectConstraintsRecursive(nodes: [DependencyNode], into result: inout [String: Set<String>]) {
        for node in nodes {
            if node.isConstraint {
                let coordinate = node.coordinate
                let version = node.resolvedVersion ?? node.requestedVersion
                result[coordinate, default: []].insert(version)
            }
            collectConstraintsRecursive(nodes: node.children, into: &result)
        }
    }

    // MARK: - Version Parsing

    struct SemanticVersion: Comparable {
        let major: Int
        let minor: Int
        let patch: Int

        static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }
    }

    static func parseVersion(_ versionString: String) -> SemanticVersion? {
        // Strip qualifiers: .Final, .RELEASE, -jre, -beta1, -SNAPSHOT, etc.
        var cleaned = versionString
        // Remove trailing qualifier after hyphen (e.g., -jre, -beta1, -SNAPSHOT)
        if let hyphenRange = cleaned.range(of: "-") {
            let suffix = String(cleaned[hyphenRange.upperBound...])
            // Only strip if it's not purely numeric
            if !suffix.allSatisfy({ $0.isNumber || $0 == "." }) {
                cleaned = String(cleaned[..<hyphenRange.lowerBound])
            }
        }
        // Remove trailing dot-qualifier (e.g., .Final, .RELEASE)
        let dotQualifiers = [".Final", ".RELEASE", ".GA", ".SP"]
        for qualifier in dotQualifiers {
            if cleaned.hasSuffix(qualifier) {
                cleaned = String(cleaned.dropLast(qualifier.count))
            }
        }

        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }

        let major = parts[0]
        let minor = parts[1]
        let patch = parts.count >= 3 ? parts[2] : 0

        return SemanticVersion(major: major, minor: minor, patch: patch)
    }
}
