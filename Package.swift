// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "UsageWidget", path: "Sources/UsageWidget")
    ]
)
