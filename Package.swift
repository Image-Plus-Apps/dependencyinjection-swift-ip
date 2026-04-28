// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "DependencyInjection",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "DependencyInjection",
            targets: ["DependencyInjection"]),
    ],
    targets: [
        .target(
            name: "DependencyInjection",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "DependencyInjectionTests",
            dependencies: ["DependencyInjection"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
    ]
)
