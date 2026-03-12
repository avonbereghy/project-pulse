// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ProjectPulse",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ProjectPulse",
            path: "Sources/ProjectPulse"
        )
    ]
)
