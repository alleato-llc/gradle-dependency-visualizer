import Foundation

public final class DependencyNode: Sendable, Identifiable, Hashable {
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

    public static func == (lhs: DependencyNode, rhs: DependencyNode) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
