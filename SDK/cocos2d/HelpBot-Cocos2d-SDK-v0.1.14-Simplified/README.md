# HelpBot SDK for Cocos2d Creator - 精简版

**版本**: v0.1.14  
**发布日期**: 2026-01-18

## 📦 包含内容

### 原生 SDK（核心功能）
- ✅ **Android**: HelpBot-release-0.1.14.aar + HelpBotCocosBridge-release.aar
- ✅ **iOS**: HelpBotSDK.xcframework + HelpBotCocosBridge.swift

### TypeScript 接口层
- ✅ **HelpBotSDK.ts** - 单文件接口封装（300 行）

### 示例代码
- ✅ **Example.ts** - 完整使用示例

---

## 🎯 核心理念

**TypeScript 只做一件事：统一接口 + 平台判断 + 调用原生**

```
┌─────────────────────────────────┐
│  HelpBotSDK.ts (TypeScript)     │  ← 只是接口封装
│  - 平台自动检测                  │
│  - 统一 API 接口                 │
│  - 调用原生 SDK                  │
└─────────────────────────────────┘
            ↓ 自动判断平台
┌─────────────────────────────────┐
│  原生 SDK (AAR/XCFramework)     │  ← 所有核心功能
│  - WebView 容器                  │
│  - 网络通信                      │
│  - UI 管理                       │
│  - 所有业务逻辑                  │
└─────────────────────────────────┘
```

---

## 🚀 快速开始

### 1. Android 集成

将 `android/` 目录下的 AAR 文件复制到 Creator 导出工程的 `app/libs/` 目录：

```gradle
dependencies {
    implementation files('libs/HelpBot-release-0.1.14.aar')
    implementation files('libs/HelpBotCocosBridge-release.aar')
}
```

### 2. iOS 集成

1. 在 Xcode 中添加 `ios/HelpBotSDK.xcframework`
2. 复制 `ios/HelpBotCocosBridge.swift` 到项目

### 3. TypeScript 集成

将 `typescript/HelpBotSDK.ts` 复制到 Creator 项目的 `assets/` 目录。

### 4. 使用 SDK

```typescript
import HelpBotSDK from './HelpBotSDK';

// 获取实例
const helpBot = HelpBotSDK.getInstance();

// 监听事件（可选）
helpBot.on((eventName, data) => {
    console.log(eventName, data);
});

// 安装配置
helpBot.install({
    baseURL: 'https://your-domain.com',
    token: 'your-token',
    identifier: 'user-id'
});

// 登录
helpBot.login('user-token');

// 显示会话
helpBot.showConversation();
```

---

## ✨ 精简版优势

### 对比旧版本

| 项目 | 旧版本 | 精简版 |
|------|--------|--------|
| TypeScript 文件 | 7 个文件 | **1 个文件** ✅ |
| 代码行数 | 1000+ 行 | **300 行** ✅ |
| 平台判断 | 手动 | **自动** ✅ |
| 职责 | 重复实现很多功能 | **只做接口封装** ✅ |
| 理解难度 | 复杂 | **简单** ✅ |

### 为什么更好？

1. **职责清晰**
   - TypeScript: 只做接口封装
   - 原生 SDK: 实现所有核心功能
   - 客户一看就懂

2. **代码更少**
   - 只有 1 个 TS 文件
   - 300 行代码
   - 易于维护和混淆

3. **自动判断平台**
   - 自动检测 Android/iOS
   - 客户无需关心平台差异
   - 统一的 API 接口

4. **必须使用原生 SDK**
   - 客户清楚知道必须集成 AAR/XCFramework
   - 不会误以为只用 TS 就够了
   - 避免集成错误

---

## 📚 API 参考

### 核心方法

```typescript
// 安装配置
install(config: HelpBotConfig): void

// 用户登录
login(token: string): void

// 用户登出
logout(): void

// 显示会话
showConversation(): void

// 隐藏会话
hideConversation(): void

// 更新元数据
updateSdkMeta(meta: Record<string, any>): void
updateCustomMeta(meta: Record<string, any>): void

// 问题标签
addIssueTags(tags: string[]): void
removeIssueTags(tags: string[]): void

// 销毁 SDK
destroy(): void
```

### 诊断工具

```typescript
// 获取 SDK 版本
getSdkVersion(): string

// 检查初始化状态
isInitialized(): boolean

// 检查会话可见性
isConversationVisible(): boolean

// 清除 WebView 数据
clearWebViewData(): void

// 获取当前平台
getPlatform(): string

// 检查是否原生环境
isNative(): boolean
```

### 事件监听

```typescript
// 监听事件
on(callback: (eventName: string, data?: any) => void): void

// 移除监听
off(callback: (eventName: string, data?: any) => void): void
```

### 事件类型

- `INSTALL_SUCCESS` - 安装成功
- `INSTALL_FAILURE` - 安装失败
- `LOGIN_SUCCESS` - 登录成功
- `LOGIN_FAILURE` - 登录失败
- `CONVERSATION_SHOWN` - 会话已显示
- `CONVERSATION_HIDDEN` - 会话已隐藏
- `UNREAD_COUNT_CHANGED` - 未读消息数变化

---

## 📖 完整示例

查看 `examples/Example.ts` 获取完整的使用示例。

### Cocos Creator 组件示例

```typescript
import HelpBotSDK from './HelpBotSDK';

const { ccclass, property } = cc._decorator;

@ccclass
export default class GameMain extends cc.Component {
    
    private helpBot: HelpBotSDK;
    
    onLoad() {
        // 获取 SDK 实例
        this.helpBot = HelpBotSDK.getInstance();
        
        // 监听事件
        this.helpBot.on((eventName, data) => {
            console.log(`[HelpBot] ${eventName}`, data);
            
            if (eventName === 'UNREAD_COUNT_CHANGED') {
                this.updateUnreadBadge(data?.count || 0);
            }
        });
        
        // 安装配置
        this.helpBot.install({
            baseURL: 'https://helpbot.example.com',
            token: 'your-installation-token',
            identifier: 'user-12345'
        });
        
        // 登录
        this.helpBot.login('user-session-token');
    }
    
    // 联系客服按钮
    onContactSupportClick() {
        this.helpBot.showConversation();
    }
    
    // 用户登出
    onUserLogout() {
        this.helpBot.logout();
        this.helpBot.clearWebViewData();
    }
    
    // 更新未读消息徽章
    updateUnreadBadge(count: number) {
        // 更新 UI 显示未读消息数
    }
}
```

---

## 🔧 系统要求

- **Cocos Creator**: 2.4.x 或 3.x
- **Android**: API 21+ (Android 5.0+)
- **iOS**: 12.0+

---

## ⚠️ 重要说明

### 必须使用原生 SDK

**TypeScript 文件只是接口封装，核心功能全部在原生 SDK 中实现！**

- ✅ 必须集成 `HelpBot-release-0.1.14.aar` (Android)
- ✅ 必须集成 `HelpBotCocosBridge-release.aar` (Android)
- ✅ 必须集成 `HelpBotSDK.xcframework` (iOS)
- ✅ 必须集成 `HelpBotCocosBridge.swift` (iOS)

**只有 TypeScript 文件是无法工作的！**

### 平台自动检测

SDK 会自动检测当前平台（Android/iOS），客户无需手动判断：

```typescript
// SDK 内部自动判断平台
const helpBot = HelpBotSDK.getInstance();
helpBot.install(config); // 自动调用对应平台的原生方法
```

---

## 📝 更新日志

### v0.1.14 - 2026-01-18

**精简版发布**

- ✨ 重新设计 TypeScript SDK，从 7 个文件精简为 1 个文件
- ✨ 自动平台检测，无需手动判断 Android/iOS
- ✨ 统一 API 接口，使用更简单
- ✨ 职责清晰，TypeScript 只做接口封装
- ✨ 代码量减少 70%，从 1000+ 行减少到 300 行

---

## 📞 技术支持

- 查看 `examples/Example.ts` 获取使用示例
- 查看 `docs/` 目录获取详细文档

---

## 📄 许可证

MIT License - 详见 LICENSE.txt

---

**© 2026 HelpBot SDK Team. All rights reserved.**
