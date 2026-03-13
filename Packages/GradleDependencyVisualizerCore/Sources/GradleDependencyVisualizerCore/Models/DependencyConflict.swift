public struct DependencyConflict: Sendable, Identifiable, Hashable {
    public let id: String
    public let coordinate: String
    public let requestedVersion: String
    public let resolvedVersion: String
    public let requestedBy: String

    public init(
        coordinate: String,
        requestedVersion: String,
        resolvedVersion: String,
        requestedBy: String
    ) {
        self.id = "\(coordinate):\(requestedVersion)->\(resolvedVersion):\(requestedBy)"
        self.coordinate = coordinate
        self.requestedVersion = requestedVersion
        self.resolvedVersion = resolvedVersion
        self.requestedBy = requestedBy
    }
}
