// swift-tools-version: 6.0
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
            targets: ["HelpBotSDK"]
        )
    ],
    // 重要：Xcode 26（Swift 6 编译器）下，为避免严格并发规则将历史代码升级为 error，
    // 这里显式锁定 Swift 5 语言模式（仅影响语言模式，不影响使用新版编译器）。
    swiftLanguageModes: [.v5],
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
    ]
)


