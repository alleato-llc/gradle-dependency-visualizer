// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GradleDependencyVisualizerServices",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GradleDependencyVisualizerServices", targets: ["GradleDependencyVisualizerServices"]),
    ],
    dependencies: [
        .package(path: "../GradleDependencyVisualizerCore"),
        .package(path: "../GradleDependencyVisualizerTestSupport"),
    ],
    targets: [
        .target(
            name: "GradleDependencyVisualizerServices",
            dependencies: ["GradleDependencyVisualizerCore"],
            path: "Sources/GradleDependencyVisualizerServices"
        ),
        .testTarget(
            name: "GradleDependencyVisualizerServicesTests",
            dependencies: [
                "GradleDependencyVisualizerServices",
                .product(name: "GradleDependencyVisualizerTestSupport", package: "GradleDependencyVisualizerTestSupport"),
            ],
            path: "Tests/GradleDependencyVisualizerServicesTests"
        ),
    ]
)
