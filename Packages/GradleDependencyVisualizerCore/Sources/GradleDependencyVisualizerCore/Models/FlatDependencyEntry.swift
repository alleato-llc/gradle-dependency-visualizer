public struct FlatDependencyEntry: Sendable, Identifiable, Hashable {
    public let id: String
    public let group: String
    public let artifact: String
    public let coordinate: String
    public let version: String
    public let hasConflict: Bool
    public let isOmitted: Bool
    public let occurrenceCount: Int
    public let usedBy: [String]
    public let versions: Set<String>

    public init(
        group: String,
        artifact: String,
        coordinate: String,
        version: String,
        hasConflict: Bool,
        isOmitted: Bool,
        occurrenceCount: Int,
        usedBy: [String],
        versions: Set<String>
    ) {
        self.id = coordinate
        self.group = group
        self.artifact = artifact
        self.coordinate = coordinate
        self.version = version
        self.hasConflict = hasConflict
        self.isOmitted = isOmitted
        self.occurrenceCount = occurrenceCount
        self.usedBy = usedBy
        self.versions = versions
    }
}
