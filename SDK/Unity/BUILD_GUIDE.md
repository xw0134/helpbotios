# Unity 手动构建指南

## 方法一: 使用 Unity Hub (推荐)

### 步骤 1: 打开项目

1. 启动 Unity Hub
2. 点击 "Projects" 标签
3. 点击 "Add" 按钮
4. 浏览到: `D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\SDK\Unity`
5. 选择该文件夹并点击 "Select Folder"
6. 双击项目打开 Unity 编辑器

### 步骤 2: 配置 Android 构建设置

1. 在 Unity 编辑器中,点击 `File` → `Build Settings`
2. 在 Platform 列表中选择 `Android`
3. 如果 Android 旁边显示 "Switch Platform",点击它并等待切换完成
4. 点击 `Player Settings` 按钮

### 步骤 3: 配置 Player Settings

在 Player Settings 窗口中:

**Company Name**: 设置为 `DefaultCompany` 或您的公司名

**Product Name**: 设置为 `HelpBotDemo`

**Package Name**: 
- 点击 `Other Settings` 部分
- 设置 `Package Name` 为: `com.helpbot.unitydemo`

**Minimum API Level**: 
- 设置为 `Android 5.0 'Lollipop' (API level 21)` 或更高

**Target API Level**: 
- 设置为 `Automatic (highest installed)`

### 步骤 4: 添加场景

1. 在 Build Settings 窗口中,查看 "Scenes In Build" 部分
2. 如果列表为空,点击 `Add Open Scenes` 按钮
3. 或者点击 `Add` 按钮,浏览到 `Assets/Scenes/HelpBotDemo.unity`

**注意**: 如果场景不存在,它会在构建时自动创建(BuildScript.cs 会处理)

### 步骤 5: 构建 APK

**选项 A: Build**
1. 在 Build Settings 窗口中,点击 `Build` 按钮
2. 选择输出位置: `SDK/Unity/Builds/Android/HelpBotDemo.apk`
3. 点击 `Save` 开始构建
4. 等待构建完成(可能需要 5-15 分钟)

**选项 B: Build And Run** (如果已连接 Android 设备)
1. 确保 Android 设备已连接并启用 USB 调试
2. 点击 `Build And Run` 按钮
3. 选择输出位置
4. Unity 会自动构建并安装到设备

### 步骤 6: 验证输出

构建完成后,检查:
- APK 文件位置: `SDK/Unity/Builds/Android/HelpBotDemo.apk`
- APK 大小: 约 25-35 MB
- 构建日志: 查看 Unity Console 窗口

---

## 方法二: 使用 Unity 编辑器菜单 (更简单)

### 前提条件

确保 `BuildScript.cs` 已存在于 `Assets/Editor/BuildScript.cs`

### 步骤

1. 打开 Unity 项目 (使用 Unity Hub)
2. 在顶部菜单栏,点击 `HelpBot` → `Build Android APK`
3. 等待构建完成
4. APK 将输出到: `Builds/Android/HelpBotDemo.apk`

---

## 方法三: 命令行构建 (需要许可证)

### 激活许可证

如果您有 Unity 序列号:

```powershell
& "D:\Program Files\Unity\2022.3.62f3c1\Editor\Unity.exe" `
  -quit -batchmode `
  -serial "YOUR-SERIAL-NUMBER" `
  -username "your@email.com" `
  -password "yourpassword"
```

### 执行构建

```powershell
cd "D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\SDK\Unity"

& "D:\Program Files\Unity\2022.3.62f3c1\Editor\Unity.exe" `
  -quit -batchmode `
  -projectPath . `
  -buildTarget Android `
  -executeMethod BuildScript.BuildAndroid `
  -logFile build_log.txt
```

### 检查结果

```powershell
# 查看日志
Get-Content build_log.txt -Tail 50

# 检查 APK
Get-ChildItem -Path "Builds\Android" -Filter "*.apk"
```

---

## 常见问题

### 问题 1: "No valid Android SDK found"

**解决方案**:
1. 打开 Unity Hub
2. 点击 `Installs` 标签
3. 找到 Unity 2022.3.62f3c1
4. 点击齿轮图标 → `Add Modules`
5. 勾选 `Android Build Support`
   - Android SDK & NDK Tools
   - OpenJDK
6. 点击 `Install` 并等待完成

### 问题 2: "Unable to list target platforms"

**解决方案**:
1. 在 Unity 编辑器中,点击 `Edit` → `Preferences`
2. 选择 `External Tools`
3. 确保 Android SDK 路径正确
4. 如果为空,点击 `Browse` 并选择 Android SDK 位置
   - 通常在: `C:\Users\<用户名>\AppData\Local\Android\Sdk`

### 问题 3: Gradle 构建失败

**解决方案**:
1. 在 Player Settings 中
2. 找到 `Publishing Settings`
3. 取消勾选 `Custom Main Gradle Template`
4. 取消勾选 `Custom Gradle Properties Template`
5. 使用 Unity 默认的 Gradle 配置

### 问题 4: 场景缺失

**解决方案**:
BuildScript.cs 会自动创建场景,但如果需要手动创建:
1. 在 Unity 编辑器中,点击 `File` → `New Scene`
2. 点击 `File` → `Save As`
3. 保存到: `Assets/Scenes/HelpBotDemo.unity`
4. 在 Hierarchy 窗口中,右键 → `UI` → `Canvas`
5. 添加 HelpBotDemoUI 组件到场景中

---

## 安装 APK 到设备

### 使用 ADB

```powershell
# 检查设备连接
adb devices

# 安装 APK
adb install -r "D:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo\SDK\Unity\Builds\Android\HelpBotDemo.apk"

# 启动应用
adb shell am start -n com.helpbot.unitydemo/com.unity3d.player.UnityPlayerActivity
```

### 直接复制

1. 将 APK 文件复制到手机
2. 在手机上点击 APK 文件
3. 允许安装未知来源应用
4. 点击 "安装"

---

## 推荐方法

**最简单**: 方法一 (Unity Hub) - 适合初次构建

**最快速**: 方法二 (编辑器菜单) - 如果 BuildScript 已配置

**自动化**: 方法三 (命令行) - 适合 CI/CD,但需要许可证

**无需许可证**: 使用 GitHub Actions (GameCI) - 推荐用于团队协作

---

## 构建时间参考

- 首次构建: 10-20 分钟 (需要下载依赖)
- 后续构建: 3-8 分钟 (增量构建)
- 使用 SSD: 可减少 30-50% 时间

---

## 验证构建成功

构建成功的标志:
1. ✅ Unity Console 显示 "Build succeeded"
2. ✅ APK 文件存在于输出目录
3. ✅ APK 大小合理 (25-35 MB)
4. ✅ 可以安装到 Android 设备
5. ✅ 应用可以正常启动

---

**建议**: 首次构建使用 Unity Hub (方法一),熟悉流程后可以使用编辑器菜单(方法二)加快速度。
