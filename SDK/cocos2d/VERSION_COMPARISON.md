# HelpBot Cocos2d SDK - 版本对比

## 两个版本

我们提供了两个版本的 Cocos2d SDK:

1. **标准版** - HelpBot-Cocos2d-SDK-v0.1.14.zip
2. **精简版** - HelpBot-Cocos2d-SDK-v0.1.14-Simplified.zip ⭐ **推荐**

---

## 详细对比

| 项目 | 标准版 | 精简版 ⭐ |
|------|--------|---------|
| **TypeScript 文件数** | 7 个 | **1 个** |
| **TypeScript 代码行数** | 1000+ 行 | **300 行** |
| **文件大小** | 0.91 MB | **0.89 MB** |
| **平台判断** | 手动 | **自动** |
| **职责** | 重复实现很多功能 | **只做接口封装** |
| **理解难度** | 复杂 | **简单** |
| **维护难度** | 高 | **低** |
| **Android AAR** | ✅ 相同 | ✅ 相同 |
| **iOS XCFramework** | ✅ 相同 | ✅ 相同 |
| **核心功能** | ✅ 相同 | ✅ 相同 |
| **性能** | 良好 | **更好** |

---

## 标准版 (旧设计)

### 文件结构

```
typescript/
├── HelpBotSdk.ts (568 行)
├── HelpBotNative.ts
├── HelpBotEventBus.ts
├── HelpBotTypes.ts
├── HBlogger.ts
├── HBGlobal.ts
└── index.ts
```

### 使用方式

```typescript
import { HelpBotSdk } from './HelpBotSDK/HelpBotSdk';
import { HelpBotEventBus } from './HelpBotSDK/HelpBotEventBus';
import { HelpBotEventType } from './HelpBotSDK/HelpBotTypes';

HelpBotSdk.getInstance().initialize();

HelpBotEventBus.getInstance().on(
    HelpBotEventType.CONVERSATION_SHOWN,
    (data) => { ... }
);

HelpBotSdk.getInstance().install(config)
    .then(() => ...)
    .catch(err => ...);
```

### 问题

- ❌ 文件太多，客户困惑
- ❌ 重复实现了 Promise、事件总线、日志系统
- ❌ 职责不清，客户分不清哪些是核心功能
- ❌ 维护困难，需要同时维护 TS 和原生两套逻辑

---

## 精简版 (新设计) ⭐ 推荐

### 文件结构

```
typescript/
└── HelpBotSDK.ts (1 个文件，300 行)
```

### 使用方式

```typescript
import HelpBotSDK from './HelpBotSDK';

const helpBot = HelpBotSDK.getInstance();

helpBot.on((eventName, data) => { ... });

helpBot.install(config);
```

### 优势

- ✅ 只有 1 个文件，客户一目了然
- ✅ 职责清晰：TS 只做接口封装，原生做核心功能
- ✅ 自动判断平台，客户无需关心
- ✅ 易于维护，只需要维护一个文件
- ✅ 性能更好，减少封装层

---

## 功能对比

### 核心功能（完全相同）

| 功能 | 标准版 | 精简版 |
|------|--------|--------|
| 安装配置 | ✅ | ✅ |
| 用户登录 | ✅ | ✅ |
| 显示会话 | ✅ | ✅ |
| 元数据管理 | ✅ | ✅ |
| 问题标签 | ✅ | ✅ |
| 事件监听 | ✅ | ✅ |
| 诊断工具 | ✅ | ✅ |

**结论**: 功能完全相同，因为核心功能都在原生 SDK 中实现！

---

## 代码对比

### 初始化

**标准版**:
```typescript
import { HelpBotSdk } from './HelpBotSDK/HelpBotSdk';
HelpBotSdk.getInstance().initialize();
```

**精简版**:
```typescript
import HelpBotSDK from './HelpBotSDK';
const helpBot = HelpBotSDK.getInstance(); // 自动初始化
```

### 事件监听

**标准版**:
```typescript
import { HelpBotEventBus } from './HelpBotSDK/HelpBotEventBus';
import { HelpBotEventType } from './HelpBotSDK/HelpBotTypes';

HelpBotEventBus.getInstance().on(
    HelpBotEventType.CONVERSATION_SHOWN,
    (data) => {
        console.log('会话已显示', data);
    }
);
```

**精简版**:
```typescript
helpBot.on((eventName, data) => {
    if (eventName === 'CONVERSATION_SHOWN') {
        console.log('会话已显示', data);
    }
});
```

### 安装配置

**标准版**:
```typescript
HelpBotSdk.getInstance().install(config)
    .then(() => console.log('成功'))
    .catch(err => console.error('失败', err));
```

**精简版**:
```typescript
helpBot.install(config); // 直接调用，原生处理异步
```

---

## 架构对比

### 标准版架构

```
┌─────────────────────────────────────────┐
│  TypeScript 层 (7 个文件，1000+ 行)      │
│  ├─ HelpBotSdk.ts                       │
│  ├─ HelpBotNative.ts                    │
│  ├─ HelpBotEventBus.ts ← 重复实现       │
│  ├─ HelpBotTypes.ts                     │
│  ├─ HBlogger.ts ← 重复实现              │
│  ├─ HBGlobal.ts                         │
│  └─ index.ts                            │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  原生 SDK (AAR/XCFramework)             │
│  ✅ 所有核心功能                         │
└─────────────────────────────────────────┘
```

### 精简版架构 ⭐

```
┌─────────────────────────────────────────┐
│  TypeScript 层 (1 个文件，300 行)        │
│  └─ HelpBotSDK.ts                       │
│     ├─ 平台自动检测                      │
│     ├─ 统一 API 接口                     │
│     └─ 直接调用原生                      │
└─────────────────────────────────────────┘
            ↓ 自动判断平台
┌─────────────────────────────────────────┐
│  原生 SDK (AAR/XCFramework)             │
│  ✅ 所有核心功能                         │
└─────────────────────────────────────────┘
```

---

## 客户理解度对比

### 标准版

客户看到 7 个 TS 文件会困惑：

- ❓ 为什么有这么多文件？
- ❓ 核心功能在哪里？
- ❓ 是不是可以不用 AAR？
- ❓ 这些文件都是干什么的？

### 精简版 ⭐

客户看到 1 个 TS 文件会清楚：

- ✅ 这就是个接口封装
- ✅ 核心功能在原生 SDK
- ✅ 必须使用 AAR/XCFramework
- ✅ 非常简单易懂

---

## 性能对比

| 项目 | 标准版 | 精简版 |
|------|--------|--------|
| **初始化时间** | 正常 | **更快** |
| **事件分发** | 多层封装 | **直接回调** |
| **内存占用** | 正常 | **更少** |
| **代码体积** | 1000+ 行 | **300 行** |

---

## 推荐建议

### 新项目

**强烈推荐使用精简版！**

- ✅ 代码更少，易于理解
- ✅ 职责清晰，易于维护
- ✅ 性能更好
- ✅ 客户体验更好

### 现有项目

如果已经使用标准版，可以考虑迁移到精简版：

**迁移步骤**:

1. 删除旧的 7 个 TS 文件
2. 复制新的 `HelpBotSDK.ts`
3. 更新导入语句
4. 更新事件监听代码
5. 测试验证

**迁移时间**: 约 30 分钟

---

## 总结

| 版本 | 适用场景 | 推荐度 |
|------|----------|--------|
| **标准版** | 已有项目，不想改动 | ⭐⭐⭐ |
| **精简版** | 新项目，追求简洁 | ⭐⭐⭐⭐⭐ |

**最终建议**: 使用精简版！

---

## 下载

- **标准版**: `HelpBot-Cocos2d-SDK-v0.1.14.zip` (0.91 MB)
- **精简版**: `HelpBot-Cocos2d-SDK-v0.1.14-Simplified.zip` (0.89 MB) ⭐

---

**© 2026 HelpBot SDK Team. All rights reserved.**
