// swift-tools-version: 5.7
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
    targets: [
        .target(
            name: "HelpBotSDK",
            dependencies: [],
            path: "Sources"
        )
    ]
)


