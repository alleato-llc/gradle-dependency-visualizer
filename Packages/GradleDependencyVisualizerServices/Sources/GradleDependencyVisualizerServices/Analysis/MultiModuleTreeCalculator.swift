import GradleDependencyVisualizerCore

public enum MultiModuleTreeCalculator {
    public static func assemble(
        projectName: String,
        configuration: GradleConfiguration,
        moduleTrees: [(module: GradleModule, tree: DependencyTree)]
    ) -> DependencyTree {
        var allConflicts: [DependencyConflict] = []
        var roots: [DependencyNode] = []

        for (module, tree) in moduleTrees {
            let syntheticNode = DependencyNode(
                group: projectName,
                artifact: module.name,
                requestedVersion: "module",
                children: tree.roots
            )
            roots.append(syntheticNode)
            allConflicts.append(contentsOf: tree.conflicts)
        }

        return DependencyTree(
            projectName: projectName,
            configuration: configuration,
            roots: roots,
            conflicts: allConflicts
        )
    }
}
