<#
  HelpBot SDK - Windows 一键编译 + 单元测试脚本

  背景：
  - 某些 Windows 环境的 PATH/CLASSPATH 会包含带引号的 JDK 路径片段（例如："C:\Program Files\Java\jdk-xx\bin;..."）
  - AGP 在启动 Gradle Test Executor 时会拼接 -Djava.library.path，若其中夹杂引号会导致参数错位，
    最终出现 “找不到或无法加载主类 Files\Java\...” 的假错误，导致单测无法启动。

  本脚本会：
  - 清空 CLASSPATH
  - 去除 PATH 中的引号
  - 运行编译与单元测试任务（app + HelpBot）

  用法：
  - PowerShell：.\scripts\run-tests.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "[HelpBot] sanitize env: clear CLASSPATH and remove quotes from PATH"
$env:CLASSPATH = ""
if ($env:Path) {
  $env:Path = $env:Path -replace '"', ''
}

Write-Host "[HelpBot] gradle: assembleDebug (HelpBot + app)"
& .\gradlew.bat :HelpBot:assembleDebug :app:assembleDebug --no-daemon
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[HelpBot] gradle: unit tests (HelpBot + app)"
& .\gradlew.bat :HelpBot:testDebugUnitTest :app:testDebugUnitTest --no-daemon
exit $LASTEXITCODE


