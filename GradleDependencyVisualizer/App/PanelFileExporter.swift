import AppKit
import Foundation
import UniformTypeIdentifiers
import GradleDependencyVisualizerServices

final class PanelFileExporter: FileExporter, @unchecked Sendable {
    @MainActor func saveData(_ data: Data, defaultName: String, contentType: UTType) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = defaultName

        guard panel.runModal() == .OK, let url = panel.url else { return }

        try data.write(to: url)
    }

    @MainActor func saveImageData(_ pngData: Data, defaultName: String) throws {
        try saveData(pngData, defaultName: defaultName, contentType: .png)
    }
}
