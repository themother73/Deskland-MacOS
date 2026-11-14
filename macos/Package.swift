// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Deskscape",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Deskscape", path: "Sources/Deskscape")
    ]
)
