# ========================================
# HelpBot SDK - Multi Demo Build Script (Windows PowerShell 5.1 safe)
# NOTE:
# - Keep this file ASCII-only to avoid PowerShell 5.1 encoding pitfalls on UTF-8 (no BOM).
# ========================================

param(
    [switch]$SkipAAR = $false,
    [switch]$Cocos2dOnly = $false,
    [switch]$UnityOnly = $false,
    [switch]$UnrealOnly = $false,

    # Engine locations (defaults are the user-provided paths)
    [string]$Cocos2dEngineRoot = "C:\Cocos",
    [string]$UEBinariesWin64 = "D:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64",
    [string]$UnityEditorExe = "D:\Program Files\Unity\2022.3.62f3c1\Editor\Unity.exe"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Step([string]$m) { Write-Host "`n========== $m ==========" -ForegroundColor Cyan }
function Info([string]$m) { Write-Host $m -ForegroundColor Gray }
function Ok([string]$m) { Write-Host "[OK]  $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host "[FAIL] $m" -ForegroundColor Red }

$RootDir = Split-Path -Parent $PSScriptRoot
$SDKDir = Join-Path $RootDir "SDK"
$HelpBotDir = Join-Path $RootDir "HelpBot"

Write-Host ""
Write-Host "HelpBot SDK - Multi Demo Build Tool" -ForegroundColor Magenta
Info ("RootDir: {0}" -f $RootDir)
Info ("Cocos2dEngineRoot: {0}" -f $Cocos2dEngineRoot)
Info ("UEBinariesWin64: {0}" -f $UEBinariesWin64)
Info ("UnityEditorExe: {0}" -f $UnityEditorExe)

# -----------------------
# 1) Build AAR
# -----------------------
if (-not $SkipAAR) {
    Step "1/5 Build HelpBot Android AAR"
    try {
        Push-Location $RootDir
        $gradlew = if (Test-Path ".\gradlew.bat") { ".\gradlew.bat" } else { throw "gradlew.bat not found" }
        & $gradlew :HelpBot:assembleRelease
        if ($LASTEXITCODE -ne 0) { throw ("Gradle failed, exitCode={0}" -f $LASTEXITCODE) }

        $aarPath = Join-Path $HelpBotDir "build\outputs\aar\HelpBot-release-0.1.13.aar"
        if (-not (Test-Path $aarPath)) { throw ("AAR not found: {0}" -f $aarPath) }
        $aarSize = (Get-Item $aarPath).Length / 1MB
        Ok ("AAR built: {0} MB" -f ([math]::Round($aarSize, 2)))
        Info ("AAR: {0}" -f $aarPath)
    }
    finally {
        Pop-Location
    }
}
else {
    Warn "Skip AAR build (using existing AAR)."
}

# -----------------------
# 2) Copy AAR
# -----------------------
Step "2/5 Copy AAR to engine demos"
$aarSource = Join-Path $HelpBotDir "build\outputs\aar\HelpBot-release-0.1.13.aar"
if (-not (Test-Path $aarSource)) { throw ("AAR source missing: {0}" -f $aarSource) }

$targets = @(
    @{ Name = "Cocos2d"; Path = (Join-Path $SDKDir "Cocos2d\proj.android\app\libs\HelpBot-release-0.1.13.aar") },
    @{ Name = "Unity"; Path = (Join-Path $SDKDir "Unity\Assets\Plugins\Android\HelpBot-release-0.1.13.aar") },
    @{ Name = "UnrealEngine"; Path = (Join-Path $SDKDir "UnrealEngine\Plugins\HelpBotSDK\Source\Android\libs\HelpBot-release-0.1.13.aar") }
)

foreach ($t in $targets) {
    try {
        $dir = Split-Path -Parent $t.Path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -Path $aarSource -Destination $t.Path -Force
        Ok ("{0}: AAR copied" -f $t.Name)
    }
    catch {
        Warn ("{0}: AAR copy failed: {1}" -f $t.Name, $_)
    }
}

# -----------------------
# 3) Cocos2d Android build (must be within engine root)
# -----------------------
if (-not $UnityOnly -and -not $UnrealOnly) {
    Step "3/5 Build Cocos2d Android (engine mode)"

    $cocosDemoSrc = Join-Path $SDKDir "Cocos2d"
    $cocosProjectsDir = Join-Path $Cocos2dEngineRoot "projects"
    $cocosDemoDst = Join-Path $cocosProjectsDir "HelpBotDemo"
    $cocosAndroidDir = Join-Path $cocosDemoDst "proj.android"

    if (-not (Test-Path $Cocos2dEngineRoot)) {
        Fail ("Cocos2d engine root not found: {0}" -f $Cocos2dEngineRoot)
    }
    elseif (-not (Test-Path $cocosDemoSrc)) {
        Fail ("Cocos2d demo source not found: {0}" -f $cocosDemoSrc)
    }
    else {
        try {
            if (-not (Test-Path $cocosProjectsDir)) { New-Item -ItemType Directory -Path $cocosProjectsDir -Force | Out-Null }

            Info ("Sync demo to engine projects: {0}" -f $cocosDemoDst)
            $exclude = @(
                (Join-Path $cocosDemoSrc "proj.android\app\build"),
                (Join-Path $cocosDemoSrc "proj.android\.gradle"),
                (Join-Path $cocosDemoSrc "proj.android\build"),
                (Join-Path $cocosDemoSrc "build"),
                (Join-Path $cocosDemoSrc ".git")
            )
            $xd = @()
            foreach ($p in $exclude) { $xd += @("/XD", $p) }

            & robocopy $cocosDemoSrc $cocosDemoDst /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1 @xd | Out-Null

            if (-not (Test-Path $cocosAndroidDir)) { throw ("Cocos2d Android dir missing: {0}" -f $cocosAndroidDir) }
            Push-Location $cocosAndroidDir

            $gradlew = if (Test-Path ".\gradlew.bat") { ".\gradlew.bat" } else { throw "gradlew.bat not found (Cocos2d proj.android)" }
            & $gradlew assembleRelease
            if ($LASTEXITCODE -ne 0) { throw ("Cocos2d Gradle failed, exitCode={0}" -f $LASTEXITCODE) }

            $apk = Join-Path $cocosAndroidDir "app\build\outputs\apk\release\app-release.apk"
            if (Test-Path $apk) {
                $apkSize = (Get-Item $apk).Length / 1MB
                Ok ("Cocos2d APK built: {0} MB" -f ([math]::Round($apkSize, 2)))
                Info ("APK: {0}" -f $apk)
            }
            else {
                Warn "Cocos2d APK not found at default output path."
            }
        }
        catch {
            Fail ("Cocos2d build failed: {0}" -f $_)
        }
        finally {
            Pop-Location
        }
    }
}
else {
    Warn "Skip Cocos2d build."
}

# -----------------------
# 4) Unity Android build
# -----------------------
if (-not $Cocos2dOnly -and -not $UnrealOnly) {
    Step "4/5 Build Unity Android"
    $unityProjectDir = Join-Path $SDKDir "Unity"
    if (-not (Test-Path $unityProjectDir)) {
        Fail ("Unity project not found: {0}" -f $unityProjectDir)
    }
    else {
        $unityExe = $null
        if (-not [string]::IsNullOrWhiteSpace($UnityEditorExe) -and (Test-Path -LiteralPath $UnityEditorExe)) {
            $unityExe = $UnityEditorExe
        }
        else {
            $fallback = @(
                "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe",
                "D:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe",
                "C:\Program Files\Unity\Editor\Unity.exe"
            )
            foreach ($p in $fallback) {
                $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $unityExe = $found.FullName; break }
            }
        }

        if (-not $unityExe) {
            Fail "Unity.exe not found."
        }
        else {
            Info ("Unity: {0}" -f $unityExe)
            $buildMethod = "BuildScript.BuildAndroid"
            $logFile = Join-Path $unityProjectDir "build_log.txt"
            try {
                & $unityExe -quit -batchmode -projectPath $unityProjectDir -buildTarget Android -executeMethod $buildMethod -logFile $logFile
                if ($LASTEXITCODE -eq 0) {
                    Ok "Unity build command finished (check Builds/Android output)."
                }
                else {
                    Warn ("Unity may have failed (exitCode={0}). Check log: {1}" -f $LASTEXITCODE, $logFile)
                }
            }
            catch {
                Fail ("Unity build exception: {0}" -f $_)
            }
        }
    }
}
else {
    Warn "Skip Unity build."
}

# -----------------------
# 5) UnrealEngine Android build
# -----------------------
if (-not $Cocos2dOnly -and -not $UnityOnly) {
    Step "5/5 Build UnrealEngine Android"
    $ueProjectDir = Join-Path $SDKDir "UnrealEngine"
    $ueProjectFile = Join-Path $ueProjectDir "HelpBotDemo.uproject"
    if (-not (Test-Path $ueProjectFile)) {
        Fail ("UE project not found: {0}" -f $ueProjectFile)
    }
    else {
        $runUAT = $null
        if (-not [string]::IsNullOrWhiteSpace($UEBinariesWin64) -and (Test-Path -LiteralPath $UEBinariesWin64)) {
            $engineDir = Split-Path -Parent (Split-Path -Parent $UEBinariesWin64)
            $candidate = Join-Path $engineDir "Build\BatchFiles\RunUAT.bat"
            if (Test-Path $candidate) { $runUAT = $candidate }
        }
        if (-not $runUAT) {
            $fallback = @(
                "C:\Program Files\Epic Games\UE_*\Engine\Build\BatchFiles\RunUAT.bat",
                "D:\Program Files\Epic Games\UE_*\Engine\Build\BatchFiles\RunUAT.bat",
                "D:\Epic Games\UE_*\Engine\Build\BatchFiles\RunUAT.bat"
            )
            foreach ($p in $fallback) {
                $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $runUAT = $found.FullName; break }
            }
        }

        if (-not $runUAT) {
            Fail "RunUAT.bat not found."
        }
        else {
            Info ("RunUAT: {0}" -f $runUAT)
            try {
                & $runUAT BuildCookRun -project=$ueProjectFile -platform=Android -build -cook -package -clientconfig=Development -noP4
                if ($LASTEXITCODE -eq 0) {
                    Ok "UE build command finished (check Saved/StagedBuilds/Android output)."
                }
                else {
                    Warn ("UE may have failed (exitCode={0})." -f $LASTEXITCODE)
                }
            }
            catch {
                Fail ("UE build exception: {0}" -f $_)
            }
        }
    }
}
else {
    Warn "Skip UnrealEngine build."
}

Write-Host ""
Ok "Build pipeline finished. For iOS, use GitHub Actions workflows."


