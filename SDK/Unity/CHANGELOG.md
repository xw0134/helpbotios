# HelpBot Unity SDK 更新日志

所有重要的变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2024-01-04

### 新增

#### 核心功能
- ✅ Unity C# SDK 核心层实现
- ✅ Android Native Bridge (Java)
- ✅ iOS Native Bridge (Objective-C++)
- ✅ 完整的回调机制
- ✅ 统一的错误码体系
- ✅ 事件监听系统

#### API
- `Install()` - SDK 初始化（支持多种配置方式）
- `Login()` - 用户登录认证
- `ShowConversation()` - 显示客服对话界面
- `ShowFAQs()` - 显示 FAQ 页面
- `Logout()` - 用户登出
- `Destroy()` - 销毁 SDK
- `SetEventsListener()` - 设置事件监听器
- `UpdateMasterAttributes()` - 更新主属性
- `UpdateAppAttributes()` - 更新应用属性
- `GetSDKVersion()` - 获取 SDK 版本

#### 回调接口
- `IHelpBotInitCallback` - 初始化回调接口
- `IHelpBotCallback<T>` - 通用回调接口
- `IHelpBotEventsListener` - 事件监听器接口

#### 错误码
- 初始化相关错误 (1000-1099)
- WebView 相关错误 (1100-1199)
- 网络相关错误 (1200-1299)
- 认证相关错误 (1300-1399)
- 存储相关错误 (1400-1499)
- 权限相关错误 (1500-1599)
- 其他错误 (9000-9999)

#### 事件类型
- Widget 相关事件
- 对话相关事件
- 消息相关事件
- CSAT 相关事件
- 认证相关事件
- 属性验证事件

#### Demo 应用
- 完整的测试 Demo
- Install 测试（多种配置）
- Login 测试（正常流程、错误流程）
- ShowConversation 测试
- ShowFAQs 测试
- Logout 测试
- Destroy 测试
- 事件监听测试
- 属性更新测试
- 压力测试

#### 文档
- README.md - 快速开始和 API 概览
- CHANGELOG.md - 版本更新日志
- API_REFERENCE.md - 详细 API 文档
- INTEGRATION_GUIDE.md - 平台集成指南

### 平台支持

- ✅ Android (API Level 21+)
- ✅ iOS (iOS 12.0+)
- ✅ Unity 2019.4 LTS+
- ✅ Unity 2020.3 LTS+
- ✅ Unity 2021.3 LTS+

### 技术特性

- 线程安全的 API 设计
- 主线程回调执行
- JSON 序列化/反序列化
- 完整的错误处理
- 统一的日志系统
- 内存管理优化

### 已知问题

无

### 安全性

- JWT Token 认证
- HTTPS 强制要求
- 参数验证
- 错误信息脱敏

---

## 版本说明

### 版本号格式

版本号格式为 `MAJOR.MINOR.PATCH`：

- **MAJOR**: 不兼容的 API 变更
- **MINOR**: 向后兼容的功能新增
- **PATCH**: 向后兼容的问题修正

### 更新类型

- **新增 (Added)**: 新功能
- **变更 (Changed)**: 现有功能的变更
- **废弃 (Deprecated)**: 即将移除的功能
- **移除 (Removed)**: 已移除的功能
- **修复 (Fixed)**: 问题修复
- **安全 (Security)**: 安全性相关的修复

---

## 未来计划

### v1.1.0 (计划中)

- [ ] 支持更多事件类型
- [ ] 优化初始化性能
- [ ] 增强错误诊断
- [ ] 支持自定义 UI 主题

### v1.2.0 (计划中)

- [ ] 离线消息支持
- [ ] 文件上传功能
- [ ] 推送通知集成
- [ ] 多语言支持

---

## 反馈

如有问题或建议，请通过以下方式联系我们：

- 技术支持邮箱: support@helpbot.com
- GitHub Issues: https://github.com/helpbot/unity-sdk/issues

---

**注意**: 此 SDK 基于 HelpBot Android SDK 和 iOS SDK 构建，完全对齐原生 SDK 的 API 和功能。
