<#
PHP DOWNLOADER FOR XAMPP
========================
Purpose:     Downloads PHP Thread-Safe builds from windows.php.net
             and extracts them directly into C:\xampp.
             Creates php.ini with common extensions already enabled.

Why this exists:
  - PHP zip files are ~30MB, too large to bundle in git
  - Downloading manually is error-prone (wrong version, wrong architecture)
  - This script ensures you get the exact Thread-Safe x64 build needed

Usage:       Double-click download-php.bat (shows menu), or:
             powershell -ExecutionPolicy Bypass -File download-php.ps1 -Version 7.4
             powershell -ExecutionPolicy Bypass -File download-php.ps1 -Version 8.2
Requires:    PowerShell 5.1+, Administrator privileges, C:\xampp exists
#>

# Accept an optional version number (e.g. -Version 7.4)
# If omitted, the script shows an interactive menu
param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
$xamppDir = "C:\xampp"


# =====================================================
# SECTION 1: VERSION LIST & DOWNLOAD URLS
# =====================================================
# Each version needs a label (display name), key (version number),
# folder (destination directory name), and download URL.
#
# VC version notes:
#   PHP 7.4 uses VC15 (Visual C++ 2017)
#   PHP 8.0-8.3 use VS16 (Visual C++ 2019)
#   PHP 8.4 uses VS17 (Visual C++ 2022)
# You need the corresponding VC++ Redistributable installed.
$versions = @(
    @{ Label = "PHP 7.4 (VC15)"; Key = "7.4"; Folder = "php74" }
    @{ Label = "PHP 8.0 (VS16)"; Key = "8.0"; Folder = "php80" }
    @{ Label = "PHP 8.1 (VS16)"; Key = "8.1"; Folder = "php81" }
    @{ Label = "PHP 8.2 (VS16)"; Key = "8.2"; Folder = "php82" }
    @{ Label = "PHP 8.3 (VS16)"; Key = "8.3"; Folder = "php83" }
    @{ Label = "PHP 8.4 (VS17)"; Key = "8.4"; Folder = "php84" }
)

# Direct download URLs from windows.php.net
# All links point to the x64 Thread-Safe zip files
$urls = @{
    "7.4" = "https://windows.php.net/downloads/releases/archives/php-7.4.33-Win32-vc15-x64.zip"
    "8.0" = "https://windows.php.net/downloads/releases/php-8.0.30-Win32-vs16-x64.zip"
    "8.1" = "https://windows.php.net/downloads/releases/php-8.1.29-Win32-vs16-x64.zip"
    "8.2" = "https://windows.php.net/downloads/releases/php-8.2.28-Win32-vs16-x64.zip"
    "8.3" = "https://windows.php.net/downloads/releases/php-8.3.19-Win32-vs16-x64.zip"
    "8.4" = "https://windows.php.net/downloads/releases/php-8.4.5-Win32-vs17-x64.zip"
}


# =====================================================
# SECTION 2: INTERACTIVE MENU (when no version given)
# =====================================================
# If the user double-clicked the batch file or ran without -Version,
# show a numbered menu with the available PHP versions.
# Already-downloaded versions show "[installed]" next to them.
if (-not $Version) {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "     PHP Downloader for XAMPP"              -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    $i = 1
    foreach ($v in $versions) {
        # Check if this version folder already exists
        $installed = if (Test-Path (Join-Path $xamppDir $v.Folder)) { " [installed]" } else { "" }
        Write-Host "  [$i] $($v.Label)$installed"
        $i++
    }
    Write-Host "  [0] Cancel"
    Write-Host ""

    $selection = Read-Host "Select a PHP version to download"
    if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $versions.Count) {
        $Version = $versions[[int]$selection - 1].Key
    } else {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}


# =====================================================
# SECTION 3: VERSION VALIDATION
# =====================================================
# Make sure the user requested a version we know about
if (-not $urls.ContainsKey($Version)) {
    Write-Host " [ERROR] Version '$Version' is not available." -ForegroundColor Red
    Write-Host " Available: $($urls.Keys -join ', ')" -ForegroundColor Yellow
    pause
    exit 1
}

# Calculate paths
$targetDir = Join-Path -Path $xamppDir -ChildPath "php$($Version -replace '\.', '')"
$downloadUrl = $urls[$Version]
$zipFile = Join-Path -Path $env:TEMP -ChildPath "php-$Version.zip"


# =====================================================
# SECTION 4: STEP 1/4 - DOWNLOAD
# =====================================================
Clear-Host
Write-Host "=================================================="           -ForegroundColor Cyan
Write-Host " PHP $Version (TS x64) - Download and Extract"                     -ForegroundColor Cyan
Write-Host "=================================================="           -ForegroundColor Cyan
Write-Host ""

Write-Host "  URL:  $downloadUrl"                                          -ForegroundColor Gray
Write-Host "  To:   $targetDir"                                            -ForegroundColor Gray
Write-Host ""

Write-Host "  [1/4] Downloading..." -NoNewline
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($downloadUrl, $zipFile)
    Write-Host " done" -ForegroundColor Green
}
catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Yellow
    pause
    exit 1
}


# =====================================================
# SECTION 5: STEP 2/4 - EXTRACT
# =====================================================
Write-Host "  [2/4] Extracting files..." -NoNewline
try {
    # Remove old folder if it exists (e.g. re-downloading)
    if (Test-Path -LiteralPath $targetDir) {
        Remove-Item -LiteralPath $targetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
    Write-Host " done" -ForegroundColor Green
}
catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Yellow
    pause
    exit 1
}


# =====================================================
# SECTION 6: STEP 3/4 - CREATE PHP.INI
# =====================================================
# Take php.ini-development (comes with every PHP zip) and:
# 1. Copy it to php.ini
# 2. Uncomment common extensions (mysqli, curl, etc.)
# 3. Set extension_dir to the junction path so it works with the switcher
Write-Host "  [3/4] Creating php.ini..." -NoNewline
$phpIni = Join-Path -Path $targetDir -ChildPath "php.ini"
$phpIniDev = Join-Path -Path $targetDir -ChildPath "php.ini-development"
if ((Test-Path -LiteralPath $phpIniDev) -and (-not (Test-Path -LiteralPath $phpIni))) {
    $content = Get-Content -Path $phpIniDev -Raw

    # Enable extensions typically needed by XAMPP apps (phpMyAdmin, Laravel, etc.)
    $extensionsToEnable = @("curl", "fileinfo", "gd2", "mbstring", "mysqli", "openssl", "pdo_mysql")
    foreach ($ext in $extensionsToEnable) {
        # Uncomment: ";extension=mysqli" → "extension=mysqli"
        $content = $content -replace ";extension=$ext", "extension=$ext"
    }

    # Fix extension_dir: the default is commented "ext" or "./ext"
    # We set it to C:\xampp\php\ext which works through the junction
    $content = $content -replace ';extension_dir\s*=\s*"(?:\./|ext)"', 'extension_dir = "C:\xampp\php\ext"'
    $content = $content -replace 'extension_dir\s*=\s*"[^"]*"[^"]', 'extension_dir = "C:\xampp\php\ext"'

    Set-Content -Path $phpIni -Value $content -NoNewline
    Write-Host " done" -ForegroundColor Green
} else {
    Write-Host " skipped (already exists)" -ForegroundColor Yellow
}


# =====================================================
# SECTION 7: STEP 4/4 - CLEANUP
# =====================================================
Write-Host "  [4/4] Cleaning up..." -NoNewline
Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
Write-Host " done" -ForegroundColor Green


# =====================================================
# SECTION 8: DONE - SHOW NEXT STEPS
# =====================================================
Write-Host ""
Write-Host "=================================================="           -ForegroundColor Green
Write-Host " SUCCESS! PHP $Version installed at $targetDir"               -ForegroundColor Green
Write-Host "=================================================="           -ForegroundColor Green
Write-Host ""
Write-Host "  What now?" -ForegroundColor White
Write-Host "  1. Close this window" -ForegroundColor Gray
Write-Host "  2. Open switch-php.bat" -ForegroundColor Gray
Write-Host "  3. Select PHP $Version from the menu" -ForegroundColor Gray
Write-Host "  4. Restart Apache from XAMPP Control Panel" -ForegroundColor Gray
Write-Host ""
pause
