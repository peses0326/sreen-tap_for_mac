// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScreenTap",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ScreenTap", targets: ["ScreenTap"])],
    targets: [
        .target(name: "ScreenTapCore"),
        .executableTarget(name: "ScreenTap", dependencies: ["ScreenTapCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("ApplicationServices"),
            .linkedFramework("ScreenCaptureKit"), .linkedFramework("Carbon")
        ]),
        .executableTarget(name: "BrandAssets", dependencies: ["ScreenTapCore"], path: "Tools/BrandAssets"),
        .executableTarget(name: "CoreChecks", dependencies: ["ScreenTapCore"], path: "Tests/ScreenTapCoreTests")
    ]
)
