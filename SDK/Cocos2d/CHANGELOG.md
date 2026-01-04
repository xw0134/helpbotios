# HelpBot Cocos2d SDK 更新日志

## [1.0.0] - 2026-01-04

### 新增
- ✨ 首次发布 Cocos2d SDK
- ✨ 完整的 C++ API,与 Android SDK 功能对齐
- ✨ Android 平台支持(通过 JNI 桥接)
- ✨ iOS 平台支持(通过 Objective-C++ 桥接)
- ✨ 异步 API 设计(install, login 等)
- ✨ 统一的错误码体系(`HelpBotErrorCode`)
- ✨ 完整的回调机制(`HelpBotInitCallback`, `HelpBotCallback`, `HelpBotEventsListener`)
- ✨ 配置类 Builder 模式(`HelpBotConfig::Builder`)
- ✨ 日志系统(`HBLogger`)支持敏感信息脱敏
- ✨ 完整的 Demo 应用

### 核心功能
- SDK 初始化(`HelpBot::install`)
- 用户登录(`HelpBot::login`)
- 对话界面(`HelpBot::showConversation`)
- FAQ 功能(`showFAQs`, `showFAQSection`, `showSingleFAQ`)
- 元数据更新(`updateSDKMeta`, `updateCustomMeta`)
- 标签管理(`addIssueTags`, `removeIssueTags`)
- 事件监听(`setHelpBotEventsListener`)
- SSE 通知(`enableSseNotification`, `disableSseNotification`)

### 文档
- 📖 README.md - 快速开始指南
- 📖 API.md - 详细 API 文档
- 📖 INTEGRATION_GUIDE.md - 集成指南

### 已知问题
- iOS 平台桥接层为框架代码,需要实际 iOS SDK 配合使用
- Demo 应用的 HTTP 请求功能需要根据实际环境配置

---

## 版本说明

### 版本号规则
遵循语义化版本 2.0.0 (Semantic Versioning):
- 主版本号(MAJOR): 不兼容的 API 变更
- 次版本号(MINOR): 向下兼容的功能新增
- 修订号(PATCH): 向下兼容的问题修正

### 支持策略
- 最新版本: 完整支持
- 上一个主版本: 安全更新和关键 bug 修复
- 更早版本: 不再支持,建议升级
