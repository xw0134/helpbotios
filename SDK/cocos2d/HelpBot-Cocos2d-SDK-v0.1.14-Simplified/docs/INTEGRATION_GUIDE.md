# HelpBot Cocos2d SDK 集成指南 - 精简版

## 概述

本指南介绍如何在 Cocos Creator 项目中集成 HelpBot SDK 精简版。

**核心理念**: TypeScript 只做接口封装，所有核心功能由原生 SDK（AAR/XCFramework）实现。

---

## 目录

- [Android 集成](#android-集成)
- [iOS 集成](#ios-集成)
- [TypeScript 使用](#typescript-使用)
- [API 参考](#api-参考)
- [常见问题](#常见问题)

---

## Android 集成

### 步骤 1: 复制 AAR 文件

将以下文件复制到 Creator 导出的 Android 工程的 `app/libs/` 目录：

- `HelpBot-release-0.1.14.aar` - 核心 SDK
- `HelpBotCocosBridge-release.aar` - Cocos2d 桥接层

### 步骤 2: 配置 Gradle

在 `app/build.gradle` 中添加依赖：

```gradle
dependencies {
    implementation files('libs/HelpBot-release-0.1.14.aar')
    implementation files('libs/HelpBotCocosBridge-release.aar')
}
```

### 步骤 3: 配置权限

在 `AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 完成！

Android 集成完成，AAR 已包含所有必要的混淆规则。

---

## iOS 集成

### 步骤 1: 添加 XCFramework

1. 在 Xcode 中打开 Creator 导出的 iOS 工程
2. 将 `HelpBotSDK.xcframework` 拖入项目
3. 选择 "Copy items if needed" 和 "Embed & Sign"

### 步骤 2: 添加桥接层

1. 将 `HelpBotCocosBridge.swift` 复制到项目源码目录
2. 在 Xcode 中添加该文件
3. 如果提示创建桥接头文件，选择 "Create"

### 步骤 3: 配置网络权限

在 `Info.plist` 中添加：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 完成！

iOS 集成完成。

---

## TypeScript 使用

### 步骤 1: 复制 SDK 文件

将 `typescript/HelpBotSDK.ts` 复制到 Creator 项目的 `assets/` 目录。

**只需要这一个文件！**

### 步骤 2: 导入并使用

```typescript
import HelpBotSDK from './HelpBotSDK';

// 获取实例
const helpBot = HelpBotSDK.getInstance();

// 监听事件
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

### 完成！

就这么简单！SDK 会自动检测平台并调用对应的原生方法。

---

## API 参考

### 配置对象

```typescript
interface HelpBotConfig {
    baseURL: string;      // 必填: 服务器地址
    token: string;        // 必填: 安装 Token
    identifier: string;   // 必填: 用户唯一标识
    name?: string;        // 可选: 用户名称
    email?: string;       // 可选: 用户邮箱
    avatar?: string;      // 可选: 用户头像
    [key: string]: any;   // 其他自定义配置
}
```

### 核心方法

#### install(config)
安装并配置 SDK

```typescript
helpBot.install({
    baseURL: 'https://helpbot.example.com',
    token: 'your-installation-token',
    identifier: 'user-12345',
    name: '张三',
    email: 'zhangsan@example.com'
});
```

#### login(token)
用户登录

```typescript
helpBot.login('user-session-token');
```

#### logout()
用户登出

```typescript
helpBot.logout();
```

#### showConversation()
显示客服会话界面

```typescript
helpBot.showConversation();
```

#### hideConversation()
隐藏会话界面

```typescript
helpBot.hideConversation();
```

#### updateSdkMeta(meta)
更新 SDK 元数据

```typescript
helpBot.updateSdkMeta({
    version: '1.0.0',
    platform: 'cocos2d'
});
```

#### updateCustomMeta(meta)
更新自定义元数据

```typescript
helpBot.updateCustomMeta({
    vipLevel: 5,
    gameLevel: 99,
    serverName: '服务器1'
});
```

#### addIssueTags(tags)
添加问题标签

```typescript
helpBot.addIssueTags(['充值问题', '账号问题']);
```

#### removeIssueTags(tags)
移除问题标签

```typescript
helpBot.removeIssueTags(['充值问题']);
```

#### destroy()
销毁 SDK

```typescript
helpBot.destroy();
```

### 诊断方法

#### getSdkVersion()
获取 SDK 版本

```typescript
const version = helpBot.getSdkVersion();
console.log('SDK 版本:', version);
```

#### isInitialized()
检查是否已初始化

```typescript
const initialized = helpBot.isInitialized();
```

#### isConversationVisible()
检查会话是否可见

```typescript
const visible = helpBot.isConversationVisible();
```

#### clearWebViewData()
清除 WebView 数据

```typescript
helpBot.clearWebViewData();
```

#### getPlatform()
获取当前平台

```typescript
const platform = helpBot.getPlatform(); // 'android' | 'ios' | 'unknown'
```

#### isNative()
检查是否在原生环境

```typescript
const isNative = helpBot.isNative();
```

### 事件监听

#### on(callback)
监听事件

```typescript
helpBot.on((eventName, data) => {
    switch (eventName) {
        case 'INSTALL_SUCCESS':
            console.log('安装成功');
            break;
        case 'LOGIN_SUCCESS':
            console.log('登录成功');
            break;
        case 'CONVERSATION_SHOWN':
            console.log('会话已显示');
            break;
        case 'CONVERSATION_HIDDEN':
            console.log('会话已隐藏');
            break;
        case 'UNREAD_COUNT_CHANGED':
            console.log('未读消息数:', data?.count);
            break;
    }
});
```

#### off(callback)
移除事件监听

```typescript
const myCallback = (eventName, data) => { ... };
helpBot.on(myCallback);

// 移除监听
helpBot.off(myCallback);
```

### 事件类型

| 事件名 | 说明 | 数据 |
|--------|------|------|
| `INSTALL_SUCCESS` | 安装成功 | - |
| `INSTALL_FAILURE` | 安装失败 | `{ errorMessage: string }` |
| `LOGIN_SUCCESS` | 登录成功 | - |
| `LOGIN_FAILURE` | 登录失败 | `{ errorMessage: string }` |
| `CONVERSATION_SHOWN` | 会话已显示 | - |
| `CONVERSATION_HIDDEN` | 会话已隐藏 | - |
| `UNREAD_COUNT_CHANGED` | 未读消息数变化 | `{ count: number }` |

---

## 完整示例

### Cocos Creator 组件

```typescript
import HelpBotSDK from './HelpBotSDK';

const { ccclass, property } = cc._decorator;

@ccclass
export default class GameMain extends cc.Component {
    
    private helpBot: HelpBotSDK;
    
    @property(cc.Label)
    unreadBadge: cc.Label = null;
    
    onLoad() {
        // 获取 SDK 实例
        this.helpBot = HelpBotSDK.getInstance();
        
        // 检查是否在原生环境
        if (!this.helpBot.isNative()) {
            console.warn('HelpBot SDK 仅在原生环境可用');
            return;
        }
        
        // 监听事件
        this.helpBot.on(this.onHelpBotEvent.bind(this));
        
        // 安装配置
        this.helpBot.install({
            baseURL: 'https://helpbot.example.com',
            token: 'your-installation-token',
            identifier: 'user-12345',
            name: '张三',
            email: 'zhangsan@example.com'
        });
        
        // 登录
        this.helpBot.login('user-session-token');
        
        // 更新用户信息
        this.helpBot.updateCustomMeta({
            vipLevel: 5,
            gameLevel: 99,
            serverName: '服务器1'
        });
    }
    
    // 事件处理
    onHelpBotEvent(eventName: string, data?: any) {
        console.log(`[HelpBot] ${eventName}`, data);
        
        switch (eventName) {
            case 'INSTALL_SUCCESS':
                console.log('HelpBot 安装成功');
                break;
                
            case 'LOGIN_SUCCESS':
                console.log('用户登录成功');
                break;
                
            case 'UNREAD_COUNT_CHANGED':
                this.updateUnreadBadge(data?.count || 0);
                break;
                
            case 'CONVERSATION_SHOWN':
                // 暂停游戏音乐
                this.pauseGameMusic();
                break;
                
            case 'CONVERSATION_HIDDEN':
                // 恢复游戏音乐
                this.resumeGameMusic();
                break;
        }
    }
    
    // 联系客服按钮点击
    onContactSupportClick() {
        this.helpBot.showConversation();
    }
    
    // 更新未读消息徽章
    updateUnreadBadge(count: number) {
        if (this.unreadBadge) {
            this.unreadBadge.string = count > 0 ? count.toString() : '';
            this.unreadBadge.node.active = count > 0;
        }
    }
    
    // 用户登出
    onUserLogout() {
        this.helpBot.logout();
        this.helpBot.clearWebViewData();
    }
    
    // 暂停游戏音乐
    pauseGameMusic() {
        // 实现音乐暂停逻辑
    }
    
    // 恢复游戏音乐
    resumeGameMusic() {
        // 实现音乐恢复逻辑
    }
    
    onDestroy() {
        // 移除事件监听
        this.helpBot.off(this.onHelpBotEvent.bind(this));
    }
}
```

---

## 常见问题

### 1. 只有 TypeScript 文件可以工作吗？

**不可以！** TypeScript 文件只是接口封装，核心功能全部在原生 SDK 中实现。

必须同时集成：
- Android: `HelpBot-release-0.1.14.aar` + `HelpBotCocosBridge-release.aar`
- iOS: `HelpBotSDK.xcframework` + `HelpBotCocosBridge.swift`

### 2. 如何判断当前平台？

**不需要手动判断！** SDK 会自动检测平台并调用对应的原生方法。

```typescript
// SDK 内部自动判断，客户无需关心
helpBot.install(config); // 自动调用 Android 或 iOS 的原生方法
```

如果需要知道当前平台：

```typescript
const platform = helpBot.getPlatform(); // 'android' | 'ios' | 'unknown'
```

### 3. 在浏览器预览时会报错吗？

SDK 会自动检测环境，在非原生环境会输出警告但不会报错：

```typescript
if (!helpBot.isNative()) {
    console.warn('HelpBot SDK 仅在原生环境可用');
    return;
}
```

### 4. 如何调试？

使用诊断方法：

```typescript
console.log('SDK 版本:', helpBot.getSdkVersion());
console.log('当前平台:', helpBot.getPlatform());
console.log('是否原生:', helpBot.isNative());
console.log('是否初始化:', helpBot.isInitialized());
```

### 5. 事件回调不触发怎么办？

检查以下几点：

1. 确认已集成原生 SDK（AAR/XCFramework）
2. 确认在原生环境运行（不是浏览器预览）
3. 确认已调用 `install()` 和 `login()`
4. 查看原生日志确认桥接是否正常

### 6. 如何更新用户信息？

使用 `updateCustomMeta()`:

```typescript
helpBot.updateCustomMeta({
    vipLevel: 5,
    gameLevel: 99,
    serverName: '服务器1',
    lastLoginTime: new Date().toISOString()
});
```

### 7. 如何清除缓存？

用户登出时调用：

```typescript
helpBot.logout();
helpBot.clearWebViewData(); // 清除 WebView 缓存
```

---

## 最佳实践

### 1. 初始化时机

在游戏启动后尽早获取 SDK 实例：

```typescript
onLoad() {
    const helpBot = HelpBotSDK.getInstance();
    // 后续使用
}
```

### 2. 错误处理

监听错误事件：

```typescript
helpBot.on((eventName, data) => {
    if (eventName === 'INSTALL_FAILURE' || eventName === 'LOGIN_FAILURE') {
        console.error('HelpBot 错误:', data?.errorMessage);
        // 显示友好提示
    }
});
```

### 3. 性能优化

- 只在需要时显示会话界面
- 及时移除不需要的事件监听
- 用户登出时清除 WebView 数据

### 4. 用户体验

- 显示会话时暂停游戏音乐
- 显示未读消息数徽章
- 提供明显的客服入口

---

## 技术支持

查看 `examples/Example.ts` 获取更多示例代码。

---

**最后更新**: 2026-01-18  
**SDK 版本**: v0.1.14
