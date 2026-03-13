// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GradleDependencyVisualizerTestSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GradleDependencyVisualizerTestSupport", targets: ["GradleDependencyVisualizerTestSupport"]),
    ],
    dependencies: [
        .package(path: "../GradleDependencyVisualizerCore"),
        .package(path: "../GradleDependencyVisualizerServices"),
    ],
    targets: [
        .target(
            name: "GradleDependencyVisualizerTestSupport",
            dependencies: ["GradleDependencyVisualizerCore", "GradleDependencyVisualizerServices"],
            path: "Sources/GradleDependencyVisualizerTestSupport"
        ),
    ]
)
