public struct GradleModule: Sendable, Identifiable, Equatable, Hashable, Codable {
    public let id: String
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.id = path
        self.name = name
        self.path = path
    }
}
