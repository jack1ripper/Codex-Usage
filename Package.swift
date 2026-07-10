// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Codex-Usage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Codex-Usage", targets: ["Codex-Usage"])
    ],
    targets: [
        .executableTarget(
            name: "Codex-Usage",
            path: "Sources/Codex-Usage"
        ),
        .testTarget(
            name: "Codex-UsageTests",
            dependencies: ["Codex-Usage"],
            path: "Tests/Codex-UsageTests"
        )
    ]
)
