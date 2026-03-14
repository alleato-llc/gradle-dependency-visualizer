public struct DependencyConflict: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let coordinate: String
    public let requestedVersion: String
    public let resolvedVersion: String
    public let requestedBy: String
    public let riskLevel: RiskLevel?
    public let riskReason: String?

    public init(
        coordinate: String,
        requestedVersion: String,
        resolvedVersion: String,
        requestedBy: String,
        riskLevel: RiskLevel? = nil,
        riskReason: String? = nil
    ) {
        self.id = "\(coordinate):\(requestedVersion)->\(resolvedVersion):\(requestedBy)"
        self.coordinate = coordinate
        self.requestedVersion = requestedVersion
        self.resolvedVersion = resolvedVersion
        self.requestedBy = requestedBy
        self.riskLevel = riskLevel
        self.riskReason = riskReason
    }

    private enum CodingKeys: String, CodingKey {
        case coordinate, requestedVersion, resolvedVersion, requestedBy, riskLevel, riskReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordinate = try container.decode(String.self, forKey: .coordinate)
        let requestedVersion = try container.decode(String.self, forKey: .requestedVersion)
        let resolvedVersion = try container.decode(String.self, forKey: .resolvedVersion)
        let requestedBy = try container.decode(String.self, forKey: .requestedBy)
        let riskLevel = try container.decodeIfPresent(RiskLevel.self, forKey: .riskLevel)
        let riskReason = try container.decodeIfPresent(String.self, forKey: .riskReason)
        self.init(
            coordinate: coordinate,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            requestedBy: requestedBy,
            riskLevel: riskLevel,
            riskReason: riskReason
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(requestedVersion, forKey: .requestedVersion)
        try container.encode(resolvedVersion, forKey: .resolvedVersion)
        try container.encode(requestedBy, forKey: .requestedBy)
        try container.encodeIfPresent(riskLevel, forKey: .riskLevel)
        try container.encodeIfPresent(riskReason, forKey: .riskReason)
    }
}
