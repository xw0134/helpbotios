@echo off
REM ========================================
REM UnrealEngine Android 本地编译测试脚本
REM ========================================

setlocal enabledelayedexpansion

echo ========================================
echo UnrealEngine Android 编译测试
echo ========================================
echo.

REM 配置变量
set "UE_ROOT=C:\Program Files\Epic Games\UE_5.0"
set "PROJECT_ROOT=%~dp0.."
set "PROJECT_FILE=%PROJECT_ROOT%\Demo\HelpBotUEDemo.uproject"
set "OUTPUT_DIR=%PROJECT_ROOT%\Builds\Android"
set "BUILD_CONFIG=Development"

echo 检查环境...
echo.

REM 检查 UE 安装
if not exist "%UE_ROOT%\Engine\Binaries\Win64\UnrealEditor.exe" (
    echo [错误] 未找到 Unreal Engine 5.0
    echo 请修改脚本中的 UE_ROOT 变量指向正确的 UE 安装路径
    echo 当前路径: %UE_ROOT%
    pause
    exit /b 1
)
echo [OK] Unreal Engine 5.0: %UE_ROOT%

REM 检查项目文件
if not exist "%PROJECT_FILE%" (
    echo [错误] 未找到项目文件: %PROJECT_FILE%
    pause
    exit /b 1
)
echo [OK] 项目文件: %PROJECT_FILE%

REM 检查 Android SDK
if "%ANDROID_HOME%"=="" (
    echo [警告] 未设置 ANDROID_HOME 环境变量
    echo 请设置 ANDROID_HOME 指向 Android SDK 路径
    set /p ANDROID_HOME="请输入 Android SDK 路径 (例如: C:\Users\YourName\AppData\Local\Android\Sdk): "
)
echo [OK] Android SDK: %ANDROID_HOME%

REM 检查 Android NDK
if "%ANDROID_NDK_HOME%"=="" (
    if exist "%ANDROID_HOME%\ndk\25.1.8937393" (
        set "ANDROID_NDK_HOME=%ANDROID_HOME%\ndk\25.1.8937393"
    ) else (
        echo [警告] 未找到 Android NDK 25.1.8937393
        echo 请在 Android Studio 中安装 NDK 25.1.8937393
        pause
        exit /b 1
    )
)
echo [OK] Android NDK: %ANDROID_NDK_HOME%

REM 检查 JDK
java -version >nul 2>&1
if errorlevel 1 (
    echo [警告] 未找到 Java
    echo 请安装 JDK 17 或更高版本
    pause
    exit /b 1
)
echo [OK] Java 已安装

echo.
echo ========================================
echo 开始编译...
echo ========================================
echo.

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 设置 RunUAT 路径
set "RUNUAT=%UE_ROOT%\Engine\Build\BatchFiles\RunUAT.bat"

REM 执行编译
echo 执行 RunUAT BuildCookRun...
echo 配置: %BUILD_CONFIG%
echo 输出: %OUTPUT_DIR%
echo.

"%RUNUAT%" BuildCookRun ^
    -project="%PROJECT_FILE%" ^
    -platform=Android ^
    -clientconfig=%BUILD_CONFIG% ^
    -cook ^
    -stage ^
    -package ^
    -build ^
    -archive ^
    -archivedirectory="%OUTPUT_DIR%" ^
    -utf8output

if errorlevel 1 (
    echo.
    echo ========================================
    echo [错误] 编译失败
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo [成功] 编译完成!
echo ========================================
echo.

REM 查找生成的 APK
echo 查找 APK 文件...
for /r "%OUTPUT_DIR%" %%f in (*.apk) do (
    echo 找到 APK: %%f
    echo 大小: 
    dir "%%f" | findstr /R /C:"[0-9].*\.apk"
)

echo.
echo 编译产物位置: %OUTPUT_DIR%
echo.

REM 询问是否安装到设备
set /p INSTALL="是否安装到连接的 Android 设备? (y/n): "
if /i "%INSTALL%"=="y" (
    echo.
    echo 检查 ADB 连接...
    adb devices
    echo.
    
    REM 查找 APK 文件
    for /r "%OUTPUT_DIR%" %%f in (*.apk) do (
        set "APK_FILE=%%f"
        goto :install_apk
    )
    
    :install_apk
    if defined APK_FILE (
        echo 安装 APK: !APK_FILE!
        adb install -r "!APK_FILE!"
        
        if errorlevel 1 (
            echo [错误] 安装失败
        ) else (
            echo [成功] 安装完成
            echo.
            echo 启动应用...
            adb shell am start -n com.helpbot.ue.demo/com.epicgames.unreal.GameActivity
        )
    ) else (
        echo [错误] 未找到 APK 文件
    )
)

echo.
echo 按任意键退出...
pause >nul
