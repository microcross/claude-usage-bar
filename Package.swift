// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "UsageWidgetCore", path: "Sources/UsageWidgetCore"),
        .target(
            name: "UsageWidgetUI",
            dependencies: ["UsageWidgetCore"],
            path: "Sources/UsageWidgetUI"
        ),
        .executableTarget(
            name: "UsageWidget",
            dependencies: ["UsageWidgetCore", "UsageWidgetUI"],
            path: "Sources/UsageWidget"
        ),
        .testTarget(
            name: "UsageWidgetTests",
            dependencies: ["UsageWidgetCore", "UsageWidgetUI"],
            path: "Tests/UsageWidgetTests"
        )
    ]
)
