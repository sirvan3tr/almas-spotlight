// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlmasSpotlight",
    platforms: [.macOS(.v14)],
    targets: [
        // Shared logic (no UI / no AppKit dependency on NSPanel etc.)
        .target(
            name: "AlmasSpotlightCore",
            path: "Sources/AlmasSpotlightCore"
        ),
        // Main app (floating panel)
        .executableTarget(
            name: "AlmasSpotlight",
            dependencies: ["AlmasSpotlightCore"],
            path: "Sources/AlmasSpotlight"
        ),
        // CLI fuzzy-search tester
        .executableTarget(
            name: "almas-search",
            dependencies: ["AlmasSpotlightCore"],
            path: "Sources/almas-search"
        ),
    ]
)
