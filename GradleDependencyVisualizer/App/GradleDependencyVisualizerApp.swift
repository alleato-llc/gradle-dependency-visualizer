import SwiftUI

@main
struct GradleDependencyVisualizerApp: App {
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
