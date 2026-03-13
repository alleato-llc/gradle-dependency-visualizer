import Foundation
import SwiftUI

enum GradleDependencyVisualizerError: Error, LocalizedError {
    case invalidProjectPath
    case gradlewNotFound
    case parsingFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectPath:
            "The selected path is not a valid directory."
        case .gradlewNotFound:
            "No Gradle wrapper (gradlew) found in the selected directory."
        case .parsingFailed(let message):
            "Failed to parse Gradle output: \(message)"
        case .executionFailed(let message):
            "Gradle execution failed: \(message)"
        }
    }
}

@Observable @MainActor
final class ErrorPresenter {
    var currentError: GradleDependencyVisualizerError?
    var isShowingError = false

    var errorMessage: String {
        currentError?.localizedDescription ?? "An unknown error occurred."
    }

    func present(_ error: Error) {
        if let gradleError = error as? GradleDependencyVisualizerError {
            currentError = gradleError
        } else {
            currentError = .executionFailed(error.localizedDescription)
        }
        isShowingError = true
    }

    func dismiss() {
        currentError = nil
        isShowingError = false
    }
}
