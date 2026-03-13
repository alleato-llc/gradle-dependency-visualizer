public struct DependencyDiffEntry: Sendable, Identifiable, Hashable {
    public enum ChangeKind: String, Sendable, CaseIterable {
        case added
        case removed
        case versionChanged
        case unchanged
    }

    public let id: String
    public let coordinate: String
    public let changeKind: ChangeKind
    public let beforeVersion: String?
    public let afterVersion: String?
    public let beforeResolvedVersion: String?
    public let afterResolvedVersion: String?

    public init(
        coordinate: String,
        changeKind: ChangeKind,
        beforeVersion: String? = nil,
        afterVersion: String? = nil,
        beforeResolvedVersion: String? = nil,
        afterResolvedVersion: String? = nil
    ) {
        self.id = "\(coordinate):\(changeKind.rawValue)"
        self.coordinate = coordinate
        self.changeKind = changeKind
        self.beforeVersion = beforeVersion
        self.afterVersion = afterVersion
        self.beforeResolvedVersion = beforeResolvedVersion
        self.afterResolvedVersion = afterResolvedVersion
    }

    public var effectiveBeforeVersion: String? {
        beforeResolvedVersion ?? beforeVersion
    }

    public var effectiveAfterVersion: String? {
        afterResolvedVersion ?? afterVersion
    }
}
