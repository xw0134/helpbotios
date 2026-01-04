## HelpBot Unreal Demo（纯文本工程骨架）

### 目标

提供一个最小可跑通的 UE Demo 工程骨架（不包含 `.uasset` 二进制资源），用于验证：

- UE 调用 `HelpBotUE` 插件完成 install / login / showConversation
- Android SDK 事件通过 JNI 回调到 UE，并在日志中可见

### 使用方式

1. 用 Unreal Editor 新建一个空白 C++ 工程（建议 UE5.x），例如 `HelpBotUEDemo`。
2. 把插件 `SDK/UnrealEngine/HelpBotUE` 复制到该工程 `Plugins/HelpBotUE`。
3. 将本目录 `Source/HelpBotUEDemo` 下的示例代码合并到你的工程源码（或直接把本目录作为工程模板使用）。
4. 在关卡中放置 `AHelpBotDemoActor`，并在其属性中填写：
   - `channelId`：你的 channelId
   - `domain`：你的 baseURL（必须 https）
   - `token`：后端下发的 identitiesJWT
5. Android 打包运行，观察 Log：
   - `HB_INSTALL_*` / `HB_LOGIN_*` / `HB_SDK_EVENT` 等事件会持续输出。

### 事件名

事件由 `com.helpbot.ue.HelpBotUEBridge` 统一发出，均通过 `HelpBotUESubsystem.OnHelpBotEvent(eventName, payloadJson)` 派发。


