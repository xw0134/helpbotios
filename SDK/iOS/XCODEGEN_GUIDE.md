# XcodeGen 使用指南

## 什么是 XcodeGen?

XcodeGen 是一个命令行工具,用于从 YAML 配置文件生成 Xcode 项目文件 (`.xcodeproj`)。

### 优势

1. **版本控制友好**: 避免提交巨大的 `.xcodeproj` 文件
2. **减少合并冲突**: YAML 配置文件更易于合并
3. **配置即代码**: 项目配置清晰可读
4. **自动化**: 可集成到 CI/CD 流程

## 本仓库的实际策略（重要）

为满足“开箱即用、无需先生成工程即可用 Xcode 打开运行”的要求，本仓库 **已提交** `SDK/iOS/HelpBotDemo/HelpBotDemo.xcodeproj`。

同时保留 `project.yml` 的目的：
- 作为工程配置的“可读源文件”，便于审阅与跨团队维护
- 当你需要更改 bundleId/团队/部署版本/文件结构时，可以选择用 XcodeGen 重新生成（并提交变更）

换句话说：
- **默认**：直接 `open HelpBotDemo.xcodeproj` 运行
- **需要重生成时**：再使用 XcodeGen（并注意它会覆盖现有工程文件）

## 安装

### 使用 Homebrew (推荐)

```bash
brew install xcodegen
```

### 使用 Mint

```bash
mint install yonaskolb/XcodeGen
```

### 验证安装

```bash
xcodegen --version
```

## 基本使用

### 1. 创建配置文件

在项目根目录创建 `project.yml`:

```yaml
name: MyApp
options:
  deploymentTarget:
    iOS: "13.0"

targets:
  MyApp:
    type: application
    platform: iOS
    sources:
      - path: Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
```

### 2. 生成项目

```bash
cd /path/to/your/project
xcodegen generate
```

### 3. 打开项目

```bash
open MyApp.xcodeproj
```

## HelpBotDemo 配置详解

### 完整配置

```yaml
name: HelpBotDemo
options:
  deploymentTarget:
    iOS: "13.0"
  bundleIdPrefix: com.example.helpbot

packages:
  HelpBotSDK:
    path: ../HelpBotSDK

targets:
  HelpBotDemo:
    type: application
    platform: iOS
    sources:
      - path: Sources
      - path: Assets.xcassets
    info:
      path: Supporting/Info.plist
      properties:
        CFBundleDisplayName: HelpBotDemo
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.helpbot.demo
        SWIFT_VERSION: "5.7"
        ENABLE_BITCODE: NO
      configs:
        Debug:
          SWIFT_OPTIMIZATION_LEVEL: "-Onone"
        Release:
          SWIFT_OPTIMIZATION_LEVEL: "-O"
    dependencies:
      - package: HelpBotSDK
        product: HelpBotSDK
```

### 配置说明

#### options
- `deploymentTarget`: 最低支持的 iOS 版本
- `bundleIdPrefix`: Bundle ID 前缀

#### packages
定义 Swift Package 依赖:
```yaml
packages:
  HelpBotSDK:
    path: ../HelpBotSDK  # 本地路径
    # 或使用远程仓库
    # url: https://github.com/user/repo
    # version: 1.0.0
```

#### targets
定义构建目标:
- `type`: 应用类型 (application, framework, library 等)
- `platform`: 目标平台 (iOS, macOS 等)
- `sources`: 源代码路径
- `info`: Info.plist 配置
- `settings`: 构建设置
- `dependencies`: 依赖项

#### settings
构建设置分为:
- `base`: 所有配置共享的设置
- `configs`: 特定配置 (Debug/Release) 的设置

常用设置:
```yaml
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.example.app
    PRODUCT_NAME: MyApp
    SWIFT_VERSION: "5.7"
    ENABLE_BITCODE: NO
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
  configs:
    Debug:
      SWIFT_OPTIMIZATION_LEVEL: "-Onone"
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG
    Release:
      SWIFT_OPTIMIZATION_LEVEL: "-O"
      SWIFT_COMPILATION_MODE: wholemodule
```

## 常用命令

### 生成项目
```bash
xcodegen generate
```

### 指定配置文件
```bash
xcodegen generate --spec custom.yml
```

### 仅验证配置
```bash
xcodegen generate --no-env
```

### 查看帮助
```bash
xcodegen --help
```

## 工作流程

### 开发流程

1. **首次设置**
   ```bash
   cd HelpBotDemo
   xcodegen generate
   open HelpBotDemo.xcodeproj
   ```

2. **添加新文件**
   - 直接在文件系统中添加文件
   - 重新运行 `xcodegen generate`
   - Xcode 会自动刷新项目

3. **修改配置**
   - 编辑 `project.yml`
   - 运行 `xcodegen generate`
   - 重新打开项目

### 团队协作

1. **提交代码**
   ```bash
   # 只提交 project.yml,不提交 .xcodeproj
   git add project.yml Sources/ Assets.xcassets/
   git commit -m "Add new feature"
   git push
   ```

2. **拉取代码**
   ```bash
   git pull
   xcodegen generate  # 重新生成项目
   ```

## .gitignore 配置

建议在 `.gitignore` 中添加:

```gitignore
# Xcode 项目文件 (由 XcodeGen 生成)
*.xcodeproj
*.xcworkspace

# Xcode 用户数据
*.xcuserstate
xcuserdata/

# 构建产物
build/
DerivedData/

# Swift Package Manager
.swiftpm/
```

## 高级功能

### 多 Target 配置

```yaml
targets:
  MyApp:
    type: application
    platform: iOS
    sources: [Sources/App]
    dependencies:
      - target: MyFramework
  
  MyFramework:
    type: framework
    platform: iOS
    sources: [Sources/Framework]
```

### 条件编译

```yaml
settings:
  configs:
    Debug:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG STAGING
    Release:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: RELEASE
```

### 自定义脚本

```yaml
targets:
  MyApp:
    preBuildScripts:
      - script: echo "Building..."
        name: Pre-build
    postBuildScripts:
      - script: ./scripts/post-build.sh
        name: Post-build
```

## 故障排除

### 问题: 生成失败 - YAML 语法错误

**错误信息:**
```
Error: Invalid YAML
```

**解决方案:**
1. 检查 YAML 缩进 (使用空格,不用 Tab)
2. 检查特殊字符是否需要引号
3. 使用在线 YAML 验证器检查语法

### 问题: 文件未包含在项目中

**解决方案:**
1. 确认文件在 `sources` 路径下
2. 重新运行 `xcodegen generate`
3. 检查文件扩展名是否正确

### 问题: Swift Package 依赖未解析

**解决方案:**
1. 检查 `packages` 配置是否正确
2. 确认路径或 URL 正确
3. 在 Xcode 中手动解析依赖: File → Packages → Resolve Package Versions

## 最佳实践

1. **保持配置简洁**: 只配置必要的设置
2. **使用变量**: 避免重复配置
3. **分离关注点**: 大项目可拆分多个配置文件
4. **版本控制**: 提交 `project.yml`,忽略 `.xcodeproj`
5. **文档化**: 在配置中添加注释说明

## 资源链接

- [XcodeGen 官方文档](https://github.com/yonaskolb/XcodeGen)
- [XcodeGen 配置参考](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- [示例项目](https://github.com/yonaskolb/XcodeGen/tree/master/Examples)

## 相关文档

- [HelpBotDemo README](HelpBotDemo/README.md)
- [iOS SDK README](README.md)
- [GitHub Actions 编译指南](GITHUB_ACTIONS_GUIDE.md)
