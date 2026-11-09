// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LeanTab",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LeanTab", targets: ["LeanTab"])],
    targets: [
        .target(name: "LeanTabCore"),
        .executableTarget(name: "LeanTab", dependencies: ["LeanTabCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("ApplicationServices"),
            .linkedFramework("ScreenCaptureKit"), .linkedFramework("Carbon")
        ]),
        .executableTarget(name: "CoreChecks", dependencies: ["LeanTabCore"], path: "Tests/LeanTabCoreTests")
    ]
)
