# 快速开始 - HelpBot Cocos2d SDK 精简版

## 📦 包含内容

- ✅ **1 个 TypeScript 文件** - HelpBotSDK.ts (接口封装)
- ✅ **2 个 Android AAR** - 核心 SDK + 桥接层
- ✅ **iOS 组件** - XCFramework + Swift 桥接
- ✅ **示例代码** - 完整使用示例

## 🚀 3 分钟快速集成

### 1. Android (2 步)

```gradle
// 1. 复制 AAR 到 app/libs/
// 2. 添加依赖
dependencies {
    implementation files('libs/HelpBot-release-0.1.14.aar')
    implementation files('libs/HelpBotCocosBridge-release.aar')
}
```

### 2. iOS (2 步)

```
1. 添加 HelpBotSDK.xcframework 到 Xcode
2. 复制 HelpBotCocosBridge.swift 到项目
```

### 3. TypeScript (1 步)

```
复制 HelpBotSDK.ts 到 Creator 项目的 assets/ 目录
```

### 4. 使用 (5 行代码)

```typescript
import HelpBotSDK from './HelpBotSDK';

const helpBot = HelpBotSDK.getInstance();
helpBot.install({ baseURL: '...', token: '...', identifier: '...' });
helpBot.login('user-token');
helpBot.showConversation();
```

## ✨ 就这么简单！

- ✅ **自动判断平台** - 无需手动区分 Android/iOS
- ✅ **统一接口** - 一套代码，双平台运行
- ✅ **只需 1 个 TS 文件** - 300 行代码，易于理解

## 📚 详细文档

- **README.md** - 完整介绍
- **docs/INTEGRATION_GUIDE.md** - 详细集成指南
- **examples/Example.ts** - 完整示例

## ⚠️ 重要提示

**TypeScript 文件只是接口封装，核心功能在原生 SDK 中！**

必须同时集成：
- Android: AAR 文件
- iOS: XCFramework

## 🎯 核心理念

```
TypeScript (HelpBotSDK.ts)
    ↓ 自动判断平台
原生 SDK (AAR/XCFramework)
    ↓ 实现所有功能
```

---

**开始使用吧！** 🎉
