# =====================================================
#   Android Development Environment Setup Script
# =====================================================

$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   Starting Android Development Environment Setup    " -ForegroundColor Cyan
Write-Host "=====================================================`n" -ForegroundColor Cyan

# -----------------------------------------------------
# [PRE-FLIGHT CHECKS]
# -----------------------------------------------------
Write-Host "--> Running pre-flight system checks..." -ForegroundColor Cyan

# 1. Admin privileges check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  [+] Elevation: Running as Administrator." -ForegroundColor Green
} else {
    Write-Host "  [!] Elevation: Not running as Administrator. (Virtualization feature configuration will be skipped if already handled; user setup will proceed)." -ForegroundColor Yellow
}

# 2. SDK Directory validation & setup
$sdkDir = "$env:LOCALAPPDATA\Android\Sdk"
if (!(Test-Path $sdkDir)) {
    try {
        New-Item -ItemType Directory -Path $sdkDir -Force | Out-Null
        Write-Host "  [+] SDK Directory: Created $sdkDir" -ForegroundColor Green
    } catch {
        Write-Host "  [-] Error creating SDK directory: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [+] SDK Directory: Found existing at $sdkDir" -ForegroundColor Green
}

# 3. Detect Android Studio installation
$studioPath = "C:\Program Files\Android\Android Studio\bin\studio64.exe"
$studioInstalled = Test-Path $studioPath
if ($studioInstalled) {
    Write-Host "  [+] Android Studio: Detected at 'C:\Program Files\Android\Android Studio'." -ForegroundColor Green
} else {
    Write-Host "  [i] Android Studio: Not detected in standard path (will attempt install via winget)." -ForegroundColor Gray
}

# 4. Detect Android Platform-Tools (adb)
$adbPath = "$sdkDir\platform-tools\adb.exe"
$adbInstalled = Test-Path $adbPath
if ($adbInstalled) {
    Write-Host "  [+] Platform-Tools (adb): Detected at $adbPath" -ForegroundColor Green
} else {
    Write-Host "  [i] Platform-Tools (adb): Not detected (will download directly from Google CDN)." -ForegroundColor Yellow
}

# 5. Network Connectivity check
Write-Host "  [*] Checking network connectivity to Google CDN..." -ForegroundColor Gray
try {
    $testReq = [System.Net.WebRequest]::Create("https://dl.google.com")
    $testReq.Timeout = 5000
    $testReq.Method = "HEAD"
    $response = $testReq.GetResponse()
    $response.Close()
    Write-Host "  [+] Network: Google CDN reachable." -ForegroundColor Green
} catch {
    Write-Host "  [!] Network: Unable to reach dl.google.com. Downloads may fail if offline or blocked." -ForegroundColor Yellow
}

Write-Host "`nAll pre-flight checks complete. Proceeding with setup steps...`n" -ForegroundColor Cyan

# -----------------------------------------------------
# [1/4] Windows Virtualization Features
# -----------------------------------------------------
Write-Host "[1/4] Checking and enabling Windows Virtualization features..." -ForegroundColor Yellow
if ($isAdmin) {
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Host "      -> Virtualization features configured successfully." -ForegroundColor Green
    } catch {
        Write-Host "      -> Virtualization features skipped/configured." -ForegroundColor Gray
    }
} else {
    Write-Host "      -> Skipped optional Windows features (requires Administrator elevation; can be run separately if needed)." -ForegroundColor Gray
}

# -----------------------------------------------------
# [2/4] Android Studio Installation
# -----------------------------------------------------
Write-Host "`n[2/4] Checking & installing Android Studio..." -ForegroundColor Yellow
if ($studioInstalled) {
    Write-Host "      -> Android Studio is already installed. Skipping winget package installation." -ForegroundColor Green
} else {
    try {
        winget install --id Google.AndroidStudio -e --accept-package-agreements --accept-source-agreements
        Write-Host "      -> Android Studio installation completed." -ForegroundColor Green
    } catch {
        Write-Host "      -> Error installing Android Studio via winget: $_" -ForegroundColor Red
    }
}

# -----------------------------------------------------
# [3/4] Android Platform-Tools (adb, fastboot)
# -----------------------------------------------------
Write-Host "`n[3/4] Downloading & installing Android Platform-Tools (adb)..." -ForegroundColor Yellow
if ($adbInstalled) {
    Write-Host "      -> Platform-Tools (adb) already installed at $adbPath." -ForegroundColor Green
} else {
    $platformToolsUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    $tempZip = "$env:TEMP\platform-tools-latest-windows.zip"
    try {
        Write-Host "      -> Downloading latest Platform-Tools directly from Google CDN..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $platformToolsUrl -OutFile $tempZip -UseBasicParsing
        
        Write-Host "      -> Extracting to $sdkDir..." -ForegroundColor Gray
        Expand-Archive -Path $tempZip -DestinationPath $sdkDir -Force
        
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Write-Host "      -> Platform-Tools installed successfully to $sdkDir\platform-tools" -ForegroundColor Green
    } catch {
        Write-Host "      -> Failed to install Platform-Tools: $_" -ForegroundColor Red
    }
}

# -----------------------------------------------------
# [4/4] Environment Variables (ANDROID_HOME & PATH)
# -----------------------------------------------------
Write-Host "`n[4/4] Setting up Environment Variables (ANDROID_HOME & PATH)..." -ForegroundColor Yellow

# Set ANDROID_HOME and ANDROID_SDK_ROOT permanently in User environment
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkDir, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkDir, "User")
Write-Host "      -> Set ANDROID_HOME and ANDROID_SDK_ROOT to '$sdkDir'" -ForegroundColor Green

# Paths to register
$targetPaths = @(
    "$sdkDir\platform-tools",
    "$sdkDir\cmdline-tools\latest\bin",
    "$sdkDir\emulator",
    "C:\Program Files\Android\Android Studio\bin"
)

$existingPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathList = if ($existingPath) { $existingPath -split ';' } else { @() }

$addedCount = 0
foreach ($p in $targetPaths) {
    if ($pathList -notcontains $p) {
        $pathList += $p
        $addedCount++
    }
}

if ($addedCount -gt 0) {
    $updatedPath = ($pathList | Where-Object { $_ -ne "" }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
    Write-Host "      -> Added $addedCount Android SDK path(s) to User PATH." -ForegroundColor Green
} else {
    Write-Host "      -> Android SDK paths are already present in User PATH." -ForegroundColor Green
}

# Quick verification of adb
if (Test-Path "$sdkDir\platform-tools\adb.exe") {
    $adbVer = & "$sdkDir\platform-tools\adb.exe" version 2>$null | Select-Object -First 1
    if ($adbVer) {
        Write-Host "      -> Verified adb: $adbVer" -ForegroundColor Green
    }
}

Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "   SUCCESS! Android Environment is Ready to Go!      " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "You can now launch Android Studio from your Start menu or run 'adb' in new terminal windows.`n" -ForegroundColor Cyan
