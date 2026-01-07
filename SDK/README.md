# HelpBot SDK 多平台集成指南

本目录包含 HelpBot SDK 在三大主流游戏引擎（Cocos2d, Unity, Unreal Engine）的官方集成示例。

## 目录结构

| 平台 | 目录 | 说明 | 集成方式 |
| :--- | :--- | :--- | :--- |
| **Cocos2d-x** | `Cocos2d/` | C++ 项目示例 | Android JNI + iOS ObjC++ |
| **Unity** | `Unity/` | Unity 项目示例 | C# Wrapper + Android AAR + iOS Framework |
| **Unreal Engine** | `UnrealEngine/` | UE4/UE5 项目示例 | UE Plugin (C++) + APL (Android) |

## 快速开始

### 1. 准备工作

使用提供的自动化脚本构建和分发 SDK 文件：

```powershell
# Windows PowerShell
.\build_all_demos.ps1
```

此脚本会自动：
1. 编译 Android HelpBot AAR
2. 将 AAR 复制到所有 Demo 项目的对应目录
3. 尝试编译 Android 版本 Demo (如果环境满足)

### 2. 详细文档

请查阅各平台的详细集成指南：

- [Cocos2d 集成文档](Cocos2d/README.md)
- [Unity 集成文档](Unity/README.md) - *请参考 Unity 目录下的 README*
- [Unreal Engine 集成文档](UnrealEngine/README.md) - *项目根目录包含*

### 3. iOS 注意事项

iOS 版本的编译依赖于 `HelpBotSDK.framework`。
- 本地开发：请运行 `SDK/build_local.sh ` (macOS)
- 云端构建：项目配置了 GitHub Actions 自动构建 workflows

## 常见问题

### AAR 文件找不到？
请确保运行了 `build_all_demos.ps1` 脚本，或者手动复制 `HelpBot-release-0.1.13.aar` 到对应平台的 libs 目录。

### 编译失败？
每个平台都有特定的环境要求（NDK 版本，Gradle 版本等），请仔细阅读各平台的 README 文档。
