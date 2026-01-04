# ========================================
# HelpBot SDK - Auto Push Script
# ========================================

param(
    [string]$Username = "",
    [string]$Repo = "",
    [switch]$Force
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "HelpBot SDK - Auto Push Utility" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set project path
$projectPath = "d:\xinhuo\HelpBotSdkDemo\HelpBotSdkDemo"
if (-not (Test-Path $projectPath)) {
    Write-Host "Error: Project path not found: $projectPath" -ForegroundColor Red
    exit 1
}
Set-Location $projectPath

# Try to load config
$configFile = Join-Path $projectPath "github_config.ps1"
if (Test-Path $configFile) {
    Write-Host "Loading config file..." -ForegroundColor Blue
    . $configFile
    
    if (-not $Username) { $Username = $env:GITHUB_USERNAME }
    if (-not $Repo) { $Repo = $env:GITHUB_REPO }
}

# If config still missing, prompt user
if (-not $Username -or -not $Repo) {
    Write-Host "GitHub configuration not found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please select configuration mode:" -ForegroundColor Cyan
    Write-Host "1. Manual entry (Session only)" -ForegroundColor White
    Write-Host "2. Create config file (Persistent)" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Choice (1/2)"
    
    if ($choice -eq "2") {
        Write-Host ""
        Write-Host "Creating config file..." -ForegroundColor Blue
        
        $Username = Read-Host "GitHub Username"
        $Repo = Read-Host "Repository Name"
        
        $configContent = @"
# GitHub Configuration (Auto-generated)
`$env:GITHUB_USERNAME = "$Username"
`$env:GITHUB_REPO = "$Repo"
# `$env:GITHUB_TOKEN = "YOUR_TOKEN"
"@
        
        $configContent | Out-File -FilePath $configFile -Encoding UTF8
        Write-Host "Config saved to: github_config.ps1" -ForegroundColor Green
        Write-Host "Next time it will load automatically." -ForegroundColor Gray
        Write-Host ""
    }
    else {
        $Username = Read-Host "GitHub Username"
        $Repo = Read-Host "Repository Name"
    }
}

# Validate
if (-not $Username -or -not $Repo) {
    Write-Host "Error: Missing required configuration." -ForegroundColor Red
    exit 1
}

# Build URL
$repoUrl = "https://github.com/$Username/$Repo.git"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Username: $Username" -ForegroundColor White
Write-Host "Repo: $Repo" -ForegroundColor White
Write-Host "URL: $repoUrl" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Git status
Write-Host "Checking Git status..." -ForegroundColor Blue
$status = git status --porcelain
if ($status) {
    Write-Host "Uncommitted changes detected." -ForegroundColor Yellow
    git status
    Write-Host ""
    
    if (-not $Force) {
        $commit = Read-Host "Commit these changes? (y/n)"
        if ($commit -eq "y" -or $commit -eq "Y") {
            $message = Read-Host "Commit message (Enter for default)"
            if (-not $message) {
                $message = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
            
            git add .
            git commit -m $message
            Write-Host "Changes committed." -ForegroundColor Green
        }
    }
}
else {
    Write-Host "Working tree clean." -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting push process..." -ForegroundColor Blue
Write-Host ""

# Configure remote
$remotes = git remote
if ($remotes -contains "origin") {
    $currentUrl = git remote get-url origin
    if ($currentUrl -ne $repoUrl) {
        Write-Host "Remote URL mismatch, updating..." -ForegroundColor Yellow
        git remote set-url origin $repoUrl
    }
    else {
        Write-Host "Remote correctly configured." -ForegroundColor Green
    }
}
else {
    Write-Host "Adding remote origin..." -ForegroundColor Blue
    git remote add origin $repoUrl
}

# Ensure branch is main
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    Write-Host "Renaming branch to 'main'..." -ForegroundColor Blue
    git branch -M main
}

# Push
Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Blue
Write-Host "Note: Use Personal Access Token if prompted for password." -ForegroundColor Yellow
Write-Host ""

$pushStatus = git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "PUSH SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitHub Actions triggered for iOS SDK build." -ForegroundColor Green
    Write-Host ""
    Write-Host "Monitor progress here:" -ForegroundColor Cyan
    Write-Host "https://github.com/$Username/$Repo/actions" -ForegroundColor Green
    Write-Host ""
    
    # Open browser
    $openRes = Read-Host "Open Actions page in browser? (y/n)"
    if ($openRes -eq "y" -or $openRes -eq "Y") {
        Start-Process "https://github.com/$Username/$Repo/actions"
    }
}
else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "PUSH FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "1. Repo doesn't exist: Visit https://github.com/helpbotios" -ForegroundColor White
    Write-Host "2. Auth failed: Use Personal Access Token" -ForegroundColor White
    Write-Host "3. Network issues" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Write-Host "Done. Press any key to exit." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
