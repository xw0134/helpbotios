# HelpBotDemo（iOS）

## 运行方式（XcodeGen）

本 Demo 使用 XcodeGen 生成工程（避免提交巨大的 `*.pbxproj`）。

1. 安装 XcodeGen：`brew install xcodegen`
2. 进入本目录：`cd SDK/iOS/HelpBotDemo`
3. 生成工程：`xcodegen generate`
4. 打开 `HelpBotDemo.xcodeproj` 运行

## 说明

- SDK 通过本地 Swift Package 引入：`../HelpBotSDK`
- 入口页面提供：install / login / showConversation / hideConversation / logout
- 事件回调会打印到页面与 Xcode Console

## ATS（网络安全）

SDK 入口 URL 为 `https://dev-bot-server.yuedongcs.com:8443/...`（非标准端口）。若该环境证书不受信任，iOS 可能会拦截请求。

Demo 的 `Info.plist` 已对 `dev-bot-server.yuedongcs.com` 做了最小例外配置，便于测试；生产环境请务必使用可信证书并移除例外。


