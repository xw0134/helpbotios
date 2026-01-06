// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HelpBotSDK",
    defaultLocalization: "zh-Hans",
    // 重要：Xcode 26（Swift 6 编译器）下，为避免严格并发规则将历史代码升级为 error，
    // 这里显式锁定 Swift 5 语言模式（仅影响语言模式，不影响使用新版编译器）。
    swiftLanguageVersions: [.v5],
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "HelpBotSDK",
            targets: ["HelpBotSDK"]
        )
    ],
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
    ]
)


