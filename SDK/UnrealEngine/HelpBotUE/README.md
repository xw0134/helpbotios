## HelpBotUE（Unreal Engine - Android）

### 说明

`HelpBotUE` 是对现有 **Android HelpBot SDK（AAR）** 的 Unreal Engine 封装：

- **UE 蓝图节点**：Install / Login / ShowConversation / HideConversation / Logout / SendMessage / EnableSseNotification
- **事件回调**：Android `HelpBotEventsListener` 事件通过 JNI 回调到 UE，并在 `UGameInstanceSubsystem` 中统一派发
- **重要约束**：WebChat 的 `index/loader` 链接由 Android SDK 内部写死，UE 侧不提供覆盖入口（符合 SDK 规范）

### 目录结构

- `ThirdParty/Android/HelpBot-release.aar`：Android SDK AAR（来自本仓库 `HelpBot/build/outputs/aar/HelpBot-release.aar`）
- `Source/HelpBotUE/Private/Android/HelpBotUE_APL.xml`：Unreal Android 打包注入（Gradle 依赖 + AAR/Java 文件拷贝）
- `Source/HelpBotUE/Private/Android/HelpBotUEBridge.java`：Java 桥（JSON↔Map + 监听器转发）

### 快速接入（UE 工程）

1. 把本插件目录 `SDK/UnrealEngine/HelpBotUE` 复制到你的 UE 工程 `Plugins/HelpBotUE`。
2. 确认插件内已存在 `ThirdParty/Android/HelpBot-release.aar`。
3. 在 UE Editor 启用插件并重启工程。
4. 蓝图中：
   - 调用 `HelpBotUE.Install`（channelId/domain/configJson）
   - 调用 `HelpBotUE.Login`（token/loginConfigJson）
   - 调用 `HelpBotUE.ShowConversation`
5. 监听事件：
   - 在 `GameInstance` 中获取 `HelpBotUESubsystem`，绑定 `OnHelpBotEvent`。

### 注意事项（Android）

- SDK 依赖 WebView，请确保目标设备 WebView 可用。
- AAR 自带 `INTERNET` / `ACCESS_NETWORK_STATE` 权限与 `HelpBotActivity` 声明（合并到宿主 Manifest）。


