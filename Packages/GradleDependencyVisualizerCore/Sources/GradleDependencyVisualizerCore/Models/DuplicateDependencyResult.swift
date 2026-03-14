public struct DuplicateDependencyResult: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let coordinate: String
    public let kind: DuplicateKind
    public let modules: [String]
    public let versions: [String: String]
    public let hasVersionMismatch: Bool
    public let recommendation: String

    public enum DuplicateKind: String, Sendable, Hashable, Codable {
        case crossModule
        case withinModule
    }

    public init(
        coordinate: String,
        kind: DuplicateKind,
        modules: [String],
        versions: [String: String],
        hasVersionMismatch: Bool,
        recommendation: String
    ) {
        self.id = "\(kind.rawValue):\(coordinate)"
        self.coordinate = coordinate
        self.kind = kind
        self.modules = modules
        self.versions = versions
        self.hasVersionMismatch = hasVersionMismatch
        self.recommendation = recommendation
    }
}
