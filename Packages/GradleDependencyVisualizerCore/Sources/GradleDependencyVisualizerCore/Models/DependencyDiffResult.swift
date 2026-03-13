public struct DependencyDiffResult: Sendable {
    public let baselineName: String
    public let currentName: String
    public let entries: [DependencyDiffEntry]

    public init(baselineName: String, currentName: String, entries: [DependencyDiffEntry]) {
        self.baselineName = baselineName
        self.currentName = currentName
        self.entries = entries
    }

    public var added: [DependencyDiffEntry] {
        entries.filter { $0.changeKind == .added }
    }

    public var removed: [DependencyDiffEntry] {
        entries.filter { $0.changeKind == .removed }
    }

    public var versionChanged: [DependencyDiffEntry] {
        entries.filter { $0.changeKind == .versionChanged }
    }

    public var unchanged: [DependencyDiffEntry] {
        entries.filter { $0.changeKind == .unchanged }
    }
}
