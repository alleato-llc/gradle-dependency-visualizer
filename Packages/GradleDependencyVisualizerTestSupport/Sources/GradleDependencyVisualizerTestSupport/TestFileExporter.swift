import Foundation
import UniformTypeIdentifiers
import GradleDependencyVisualizerServices

public final class TestFileExporter: FileExporter, @unchecked Sendable {
    public var savedData: Data?
    public var savedDefaultName: String?
    public var savedContentType: UTType?
    public var saveCallCount = 0
    public var errorToThrow: Error?

    public init() {}

    @MainActor public func saveData(_ data: Data, defaultName: String, contentType: UTType) throws {
        saveCallCount += 1
        savedData = data
        savedDefaultName = defaultName
        savedContentType = contentType
        if let error = errorToThrow { throw error }
    }

    @MainActor public func saveImageData(_ pngData: Data, defaultName: String) throws {
        try saveData(pngData, defaultName: defaultName, contentType: .png)
    }
}
