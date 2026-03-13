public struct DependencyConflict: Sendable, Identifiable, Hashable, Codable {
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

    private enum CodingKeys: String, CodingKey {
        case coordinate, requestedVersion, resolvedVersion, requestedBy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordinate = try container.decode(String.self, forKey: .coordinate)
        let requestedVersion = try container.decode(String.self, forKey: .requestedVersion)
        let resolvedVersion = try container.decode(String.self, forKey: .resolvedVersion)
        let requestedBy = try container.decode(String.self, forKey: .requestedBy)
        self.init(
            coordinate: coordinate,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            requestedBy: requestedBy
        )
    }
}
