import Foundation
import UniformTypeIdentifiers

public protocol FileExporter: Sendable {
    @MainActor func saveData(_ data: Data, defaultName: String, contentType: UTType) throws
    @MainActor func saveImageData(_ pngData: Data, defaultName: String) throws
}
