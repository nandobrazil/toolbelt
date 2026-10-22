// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Toolbelt",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Toolbelt", path: "Sources/Toolbelt"),
        .testTarget(name: "ToolbeltTests", dependencies: ["Toolbelt"], path: "Tests/ToolbeltTests")
    ]
)
