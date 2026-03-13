import Foundation

public final class DependencyNode: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let group: String
    public let artifact: String
    public let requestedVersion: String
    public let resolvedVersion: String?
    public let isOmitted: Bool
    public let isConstraint: Bool
    public let children: [DependencyNode]

    public init(
        group: String,
        artifact: String,
        requestedVersion: String,
        resolvedVersion: String? = nil,
        isOmitted: Bool = false,
        isConstraint: Bool = false,
        children: [DependencyNode] = []
    ) {
        self.id = "\(group):\(artifact):\(requestedVersion):\(UUID().uuidString)"
        self.group = group
        self.artifact = artifact
        self.requestedVersion = requestedVersion
        self.resolvedVersion = resolvedVersion
        self.isOmitted = isOmitted
        self.isConstraint = isConstraint
        self.children = children
    }

    public var hasConflict: Bool {
        resolvedVersion != nil && resolvedVersion != requestedVersion
    }

    public var coordinate: String {
        "\(group):\(artifact)"
    }

    public var displayVersion: String {
        if let resolvedVersion {
            "\(requestedVersion) -> \(resolvedVersion)"
        } else {
            requestedVersion
        }
    }

    public var subtreeSize: Int {
        1 + children.reduce(0) { $0 + $1.subtreeSize }
    }

    private enum CodingKeys: String, CodingKey {
        case group, artifact, requestedVersion, resolvedVersion, isOmitted, isConstraint, children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(group, forKey: .group)
        try container.encode(artifact, forKey: .artifact)
        try container.encode(requestedVersion, forKey: .requestedVersion)
        try container.encodeIfPresent(resolvedVersion, forKey: .resolvedVersion)
        try container.encode(isOmitted, forKey: .isOmitted)
        try container.encode(isConstraint, forKey: .isConstraint)
        try container.encode(children, forKey: .children)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let group = try container.decode(String.self, forKey: .group)
        let artifact = try container.decode(String.self, forKey: .artifact)
        let requestedVersion = try container.decode(String.self, forKey: .requestedVersion)
        let resolvedVersion = try container.decodeIfPresent(String.self, forKey: .resolvedVersion)
        let isOmitted = try container.decode(Bool.self, forKey: .isOmitted)
        let isConstraint = try container.decode(Bool.self, forKey: .isConstraint)
        let children = try container.decode([DependencyNode].self, forKey: .children)
        self.init(
            group: group,
            artifact: artifact,
            requestedVersion: requestedVersion,
            resolvedVersion: resolvedVersion,
            isOmitted: isOmitted,
            isConstraint: isConstraint,
            children: children
        )
    }

    public static func == (lhs: DependencyNode, rhs: DependencyNode) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
