// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GradleDependencyVisualizerCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GradleDependencyVisualizerCore", targets: ["GradleDependencyVisualizerCore"]),
    ],
    targets: [
        .target(
            name: "GradleDependencyVisualizerCore",
            path: "Sources/GradleDependencyVisualizerCore"
        ),
    ]
)
