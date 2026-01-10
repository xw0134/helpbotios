// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "HelpBotSDK",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "HelpBotSDK",
            type: .dynamic,
            targets: ["HelpBotSDK"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HelpBotSDK",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("WebKit"),
                .linkedFramework("UIKit"),
                .linkedFramework("Foundation")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)


