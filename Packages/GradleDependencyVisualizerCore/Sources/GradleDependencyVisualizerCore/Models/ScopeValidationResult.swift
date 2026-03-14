public struct ScopeValidationResult: Sendable, Identifiable, Hashable {
    public let id: String
    public let coordinate: String
    public let version: String
    public let matchedLibrary: String
    public let configuration: GradleConfiguration
    public let recommendation: String

    public init(
        coordinate: String,
        version: String,
        matchedLibrary: String,
        configuration: GradleConfiguration,
        recommendation: String
    ) {
        self.id = "\(coordinate):\(version):\(configuration.rawValue)"
        self.coordinate = coordinate
        self.version = version
        self.matchedLibrary = matchedLibrary
        self.configuration = configuration
        self.recommendation = recommendation
    }
}
