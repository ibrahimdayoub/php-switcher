<#
PHP VERSION SWITCHER FOR XAMPP
==============================
Purpose:     Switch PHP versions in XAMPP by swapping a directory junction.
             Automatically fixes Apache config and php.ini for each version.
How it works:
  - XAMPP uses C:\xampp\php as the PHP directory
  - This script replaces that folder with a JUNCTION (directory symlink)
  - The junction points to the selected version folder (php74, php82, etc.)
  - Apache always sees C:\xampp\php, but gets redirected to the right version

Usage:       Double-click switch-php.bat, or run:
             powershell -ExecutionPolicy Bypass -File switch-php.ps1
Requires:    Windows (PowerShell 5.1+), Administrator, XAMPP at C:\xampp
#>

#Requires -RunAsAdministrator

# =====================================================
# SECTION 1: CONFIGURATION
# =====================================================
# To add a new PHP version, just add a new entry below.
# Folder = the subdirectory name inside C:\xampp (e.g. "php74" for C:\xampp\php74)
# MinLaravel/MaxLaravel = display info (not functional limits)
$phpVersions = @(
    @{ Id = 1; Label = "PHP 7.4"; Folder = "php74"; MinLaravel = "6.x"; MaxLaravel = "8.x" },
    @{ Id = 2; Label = "PHP 8.0"; Folder = "php80"; MinLaravel = "8.x"; MaxLaravel = "9.x" },
    @{ Id = 3; Label = "PHP 8.2"; Folder = "php82"; MinLaravel = "10.x"; MaxLaravel = "11.x" },
    @{ Id = 4; Label = "PHP 8.3"; Folder = "php83"; MinLaravel = "11.x"; MaxLaravel = "12.x" }
)

# Path to XAMPP installation
$xamppDir = "C:\xampp"

# The junction path — this is what gets pointed to different version folders
$phpSymlinkPath = Join-Path -Path $xamppDir -ChildPath "php"


# =====================================================
# SECTION 2: UI FUNCTIONS (Show-Header, Show-Menu, etc.)
# =====================================================

# Draws the application title banner
function Show-Header {
    Clear-Host
    Write-Host "=================================================="   -ForegroundColor Cyan
    Write-Host " PHP VERSION SWITCHER FOR XAMPP"                       -ForegroundColor Cyan
    Write-Host "=================================================="   -ForegroundColor Cyan
    Write-Host ""
}

# Runs php.exe through the current junction to detect active version
# Purpose: shows the user which PHP version is currently active
function Get-CurrentPhpVersion {
    $phpExe = Join-Path -Path $phpSymlinkPath -ChildPath "php.exe"
    if (Test-Path -LiteralPath $phpExe) {
        try {
            $rawVersion = & $phpExe -v 2>$null | Select-Object -First 1
            if ($rawVersion -match "PHP\s+([0-9.]+)") {
                $version = $Matches[1]
                Write-Host " Current PHP Version : " -NoNewline
                Write-Host "$version" -ForegroundColor Green
            }
            else {
                Write-Host " Current PHP Version : Detected, but couldn't parse version" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host " Current PHP Version : Unknown (failed to read)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host " Current PHP Version : No active PHP link found" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Lists all configured PHP versions with their Laravel compatibility info
function Show-Menu {
    Write-Host "--------------------------------------------------"   -ForegroundColor DarkGray
    Write-Host " Available PHP Versions:"                             -ForegroundColor White
    Write-Host "--------------------------------------------------"   -ForegroundColor DarkGray
    foreach ($v in $phpVersions) {
        Write-Host (" [{0}] {1,-8}  (Laravel {2} - {3})" -f $v.Id, $v.Label, $v.MinLaravel, $v.MaxLaravel)
    }
    Write-Host ""
    Write-Host " [0] Exit" -ForegroundColor Red
    Write-Host ""
}

# Reads user input from keyboard and validates it
# Returns: the selected version hashtable, or $null if invalid
function Get-UserChoice {
    $choice = Read-Host " Enter choice number"

    if ([string]::IsNullOrWhiteSpace($choice)) { return $null }
    if ($choice -eq "0") {
        Write-Host " Exiting. No changes made." -ForegroundColor Yellow
        exit 0
    }

    if ($choice -match '^\d+$') {
        $selection = $phpVersions | Where-Object { $_.Id -eq [int]$choice }
        return $selection
    }
    return $null
}


# =====================================================
# SECTION 3: CORE FUNCTIONS (Switch, Update, Fix)
# =====================================================

# Main switching function — orchestrates the entire version change:
# 1. Remove old junction (or backup real folder) → create new junction
# 2. Update Apache config (LoadModule, LoadFile, IfModule)
# 3. Ensure php.ini exists
# 4. Fix extension_dir to use junction-safe path
function Switch-PhpVersion {
    param([hashtable]$target)

    $targetFolder = Join-Path -Path $xamppDir -ChildPath $target.Folder

    # Check if the target version folder actually exists
    if (-not (Test-Path -LiteralPath $targetFolder)) {
        Write-Host ""
        Write-Host " [ERROR] Folder '$targetFolder' does not exist!"             -ForegroundColor Red
        Write-Host ""
        Write-Host " Make sure '$($target.Folder)' is present inside $xamppDir"  -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    # Remove existing junction, or backup the real folder (first run safety)
    if (Test-Path -LiteralPath $phpSymlinkPath) {
        # Check if it's a junction/symlink vs a real folder
        $isSymlink = (Get-Item -LiteralPath $phpSymlinkPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isSymlink) {
            Remove-Item -LiteralPath $phpSymlinkPath -Force
        }
        else {
            # First run: C:\xampp\php is XAMPP's real folder, we back it up
            $backupPath = "$phpSymlinkPath" + "_backup_" + (Get-Date -Format "yyyyMMddHHmmss")
            Rename-Item -Path $phpSymlinkPath -NewName $backupPath -Force
            Write-Host " [WARNING] Existing 'php' was a real folder. Renamed to '$backupPath' for safety." -ForegroundColor Yellow
        }
    }

    # Create the junction — this is the core of the switcher
    New-Item -ItemType Junction -Path $phpSymlinkPath -Target $targetFolder | Out-Null

    # Apply configuration fixes
    Update-ApacheConfig -target $target
    Ensure-PhpIni -target $target
    Fix-ExtensionDir -target $target

    Write-Host ""
    Write-Host " [SUCCESS] Switched to $($target.Label)"                                        -ForegroundColor Green
    Write-Host ""
    Write-Host "--------------------------------------------------"                             -ForegroundColor DarkGray
    Write-Host " Compatible Laravel : $($target.MinLaravel) - $($target.MaxLaravel)"            -ForegroundColor White
    Write-Host "--------------------------------------------------"                             -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " [ACTION REQUIRED] Restart XAMPP services (Apache) to apply the change."        -ForegroundColor Yellow
    Write-Host " Open XAMPP Control Panel and stop/start Apache"                                -ForegroundColor Cyan
    Write-Host ""

    return $true
}

# PE (Portable Executable) Parser — finds the Apache module name
# from the DLL's export table.
#
# Why this is needed:
# - PHP 8.x (XAMPP original) exports its module as "php_module"
# - PHP 7.4 (custom download) exports as "php7_module"
# - Apache's LoadModule directive must match the actual exported name
# - If they don't match, Apache crashes with "Can't locate API module structure"
#
# How it works:
#   Windows DLLs use the PE format. The export directory lists all symbols
#   the DLL makes available. We read the DLL bytes, parse the PE header,
#   walk the export name table, and look for a symbol matching "php*_module".
function Get-ApacheModuleName {
    param([string]$DllPath)

    if (-not (Test-Path -LiteralPath $DllPath)) {
        Write-Host " [WARN] DLL not found: $DllPath, defaulting to php_module" -ForegroundColor Yellow
        return "php_module"
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($DllPath)

        # Parse PE header — the standard Windows executable format
        $peOffset = [BitConverter]::ToUInt32($bytes, 0x3C) # e_lfanew — points to PE signature
        $numSections = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
        $sizeOfOptionalHeader = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
        $optionalHdrOffset = $peOffset + 24
        $sectionOffset = $optionalHdrOffset + $sizeOfOptionalHeader

        # The export directory is the 1st entry in the data directory (index 0)
        $dataDirOffset = $optionalHdrOffset + 108
        $exportRva = [BitConverter]::ToUInt32($bytes, $dataDirOffset + 4)

        if ($exportRva -eq 0) {
            Write-Host " [WARN] No export directory in $DllPath" -ForegroundColor Yellow
            return "php_module"
        }

        # Find which section (e.g. .text, .data, .rdata) contains the export dir
        $secVA = 0; $secRaw = 0
        for ($i = 0; $i -lt $numSections; $i++) {
            $s = $sectionOffset + $i * 40
            $sv = [BitConverter]::ToUInt32($bytes, $s + 12)          # VirtualAddress
            $sr = [BitConverter]::ToUInt32($bytes, $s + 20)          # PointerToRawData
            $sz = [Math]::Max(
                [BitConverter]::ToUInt32($bytes, $s + 8),            # VirtualSize
                [BitConverter]::ToUInt32($bytes, $s + 16)            # SizeOfRawData
            )
            if ($exportRva -ge $sv -and $exportRva -lt ($sv + $sz)) {
                $secVA = $sv; $secRaw = $sr; break
            }
        }

        if ($secVA -eq 0) {
            Write-Host " [WARN] Export directory not found in any section" -ForegroundColor Yellow
            return "php_module"
        }

        # Convert RVA (Relative Virtual Address) to file offset
        $efo = $exportRva - $secVA + $secRaw
        $numNames = [BitConverter]::ToUInt32($bytes, $efo + 24)       # NumberOfNames
        $aonRva = [BitConverter]::ToUInt32($bytes, $efo + 32)         # AddressOfNames
        $aonFO = $aonRva - $secVA + $secRaw

        # Walk through all exported names looking for "php*_module"
        for ($i = 0; $i -lt $numNames; $i++) {
            $nr = [BitConverter]::ToUInt32($bytes, $aonFO + $i*4)
            $no = $nr - $secVA + $secRaw
            $nm = [System.Text.Encoding]::ASCII.GetString($bytes, $no, 60) -replace "`0.*", ""
            if ($nm -match '^php\d*_module$') { return $nm }
        }

        Write-Host " [WARN] No php*_module export found in $DllPath" -ForegroundColor Yellow
    }
    catch {
        Write-Host " [WARN] Could not parse PE exports from $DllPath : $_" -ForegroundColor Yellow
    }

    return "php_module"
}

# Updates Apache's httpd-xampp.conf with 3 critical fixes:
#
# Fix 1: LoadModule
#   Apache uses LoadModule to load PHP as an Apache module.
#   The module name must match what the DLL exports.
#   Example: LoadModule php7_module "C:/xampp/php/php7apache2_4.dll"
#
# Fix 2: LoadFile
#   Each PHP version has a different core DLL (php8ts.dll, php7ts.dll).
#   This must match or Apache won't find PHP's core functions.
#
# Fix 3: IfModule block
#   PHPIniDir (which tells PHP where to find php.ini) is wrapped in
#   <IfModule php_module>. If the loaded module is "php7_module" but
#   the IfModule says "php_module", the block is skipped → PHP has no
#   php.ini → extensions_dir defaults to compiled-in path → everything breaks.
function Update-ApacheConfig {
    param([hashtable]$target)

    $targetFolder = Join-Path -Path $xamppDir -ChildPath $target.Folder

    # Find the Apache module DLL (php*apache2_4.dll) and the TS core DLL (php*ts.dll)
    $moduleDll = Get-ChildItem -Path $targetFolder -Filter "*apache2_4.dll" | Select-Object -First 1
    $tsDll = Get-ChildItem -Path $targetFolder -Filter "*ts.dll" | Where-Object { $_.Name -match '^php\d+ts\.dll$' } | Select-Object -First 1

    if (-not $moduleDll) {
        Write-Host " [WARNING] No Apache PHP module DLL found in $targetFolder" -ForegroundColor Yellow
        Write-Host " Make sure you downloaded the Thread-Safe (TS) version of PHP." -ForegroundColor Yellow
        return $false
    }

    # Detect the actual module name from the DLL's export table
    $moduleName = Get-ApacheModuleName -DllPath $moduleDll.FullName

    $confPaths = @(
        Join-Path -Path $xamppDir -ChildPath "apache\conf\extra\httpd-xampp.conf"
    )

    foreach ($confPath in $confPaths) {
        if (-not (Test-Path -LiteralPath $confPath)) { continue }

        $confContent = Get-Content -Path $confPath -Raw
        $changed = $false

        # Fix 1: Update LoadModule directive
        # Regex matches: LoadModule <any_word> "<any_path>"
        if ($confContent -match 'LoadModule\s+\w+\s+"[^"]*"') {
            $confContent = $confContent -replace 'LoadModule\s+\w+\s+"[^"]*"', "LoadModule $moduleName `"C:/xampp/php/$($moduleDll.Name)`""
            Write-Host " [INFO] Apache module updated: $moduleName ($($moduleDll.Name))" -ForegroundColor Cyan
            $changed = $true
        }

        # Fix 2: Update IfModule block name
        # Uses php\d*_module to match: php_module, php7_module, php8_module, etc.
        # This ensures switching from 7.4 back to 8.2 updates the block correctly
        if ($confContent -match '<IfModule\s+php\d*_module\s*>') {
            $confContent = $confContent -replace '<IfModule\s+php\d*_module\s*>', "<IfModule $moduleName>"
            Write-Host " [INFO] IfModule updated: $moduleName" -ForegroundColor Cyan
            $changed = $true
        }

        # Fix 3: Update LoadFile for the TS core DLL
        if ($tsDll -and $confContent -match 'LoadFile\s+"[^"]*php\d+ts\.dll"') {
            $confContent = $confContent -replace 'LoadFile\s+"[^"]*php\d+ts\.dll"', "LoadFile `"C:/xampp/php/$($tsDll.Name)`""
            Write-Host " [INFO] PHP TS DLL updated: $($tsDll.Name)" -ForegroundColor Cyan
            $changed = $true
        }

        if ($changed) {
            Set-Content -Path $confPath -Value $confContent -NoNewline
        }
        else {
            Write-Host " [WARNING] Could not find expected PHP directives in $($confPath -replace '.*\\', '')" -ForegroundColor Yellow
        }
    }

    return $true
}

# Ensures php.ini exists in the target version folder.
# If missing, copies php.ini-development (which comes with every PHP zip).
function Ensure-PhpIni {
    param([hashtable]$target)

    $targetFolder = Join-Path -Path $xamppDir -ChildPath $target.Folder
    $phpIniPath = Join-Path -Path $targetFolder -ChildPath "php.ini"
    $phpIniDevPath = Join-Path -Path $targetFolder -ChildPath "php.ini-development"

    if (-not (Test-Path -LiteralPath $phpIniPath)) {
        if (Test-Path -LiteralPath $phpIniDevPath) {
            Copy-Item -Path $phpIniDevPath -Destination $phpIniPath
            Write-Host " [INFO] Created php.ini from php.ini-development" -ForegroundColor Cyan
        }
        else {
            Write-Host " [WARNING] No php.ini or php.ini-development found in target" -ForegroundColor Yellow
        }
    }
}

# Fixes extension_dir in php.ini to use the junction path.
#
# The problem:
#   PHP 7.4's php.ini hardcodes: extension_dir = "C:\xampp\php74\ext"
#   But through the junction, Apache reads: C:\xampp\php\php.ini
#   The path "C:\xampp\php74\ext" doesn't exist when accessed as "C:\xampp\php\ext"
#
# The fix:
#   Rewrite to: extension_dir = "C:\xampp\php\ext"
#   Since C:\xampp\php → junction → C:\xampp\php74
#   C:\xampp\php\ext → junction → C:\xampp\php74\ext ✓
function Fix-ExtensionDir {
    param([hashtable]$target)

    $targetFolder = Join-Path -Path $xamppDir -ChildPath $target.Folder
    $phpIniPath = Join-Path -Path $targetFolder -ChildPath "php.ini"

    if (-not (Test-Path -LiteralPath $phpIniPath)) { return }

    $content = Get-Content -Path $phpIniPath -Raw

    # Match: extension_dir = "C:\xampp\php74\ext" or "C:\xampp\php74"
    if ($content -match 'extension_dir\s*=\s*"C:\\xampp\\php\d+\\(?:ext)?"') {
        $content = $content -replace 'extension_dir\s*=\s*"C:\\xampp\\php\d+\\ext"', 'extension_dir = "C:\xampp\php\ext"'
        Set-Content -Path $phpIniPath -Value $content -NoNewline
        Write-Host " [INFO] Fixed extension_dir to use junction path: C:\xampp\php\ext" -ForegroundColor Cyan
    }
    elseif ($content -match 'extension_dir\s*=\s*"C:\\xampp\\php\d+"') {
        $content = $content -replace 'extension_dir\s*=\s*"C:\\xampp\\php\d+"', 'extension_dir = "C:\xampp\php\ext"'
        Set-Content -Path $phpIniPath -Value $content -NoNewline
        Write-Host " [INFO] Fixed extension_dir to use junction path: C:\xampp\php\ext" -ForegroundColor Cyan
    }
}


# =====================================================
# SECTION 4: XAMPP EXISTENCE CHECK
# =====================================================
# Before showing the menu, verify that XAMPP is actually installed.
if (-not (Test-Path -LiteralPath $xamppDir)) {
    Clear-Host
    Write-Host "=================================================="   -ForegroundColor Red
    Write-Host " XAMPP NOT FOUND!"                                     -ForegroundColor Red
    Write-Host "=================================================="   -ForegroundColor Red
    Write-Host ""
    Write-Host " XAMPP is not installed at: $xamppDir"                -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Please install XAMPP on drive C: first."            -ForegroundColor White
    Write-Host " Download from: https://www.apachefriends.org/"      -ForegroundColor Cyan
    Write-Host ""
    Write-Host " After installation, run this script again."         -ForegroundColor White
    Write-Host ""
    pause
    exit 1
}


# =====================================================
# SECTION 5: MAIN APPLICATION LOOP
# =====================================================
# Runs continuously until the user picks a valid version (or exits).
# On successful switch: exits after the user presses a key.
$running = $true
while ($running) {
    Show-Header
    Get-CurrentPhpVersion
    Show-Menu

    $selected = Get-UserChoice

    if (-not $selected) {
        # Invalid input — show error and loop
        Write-Host ""
        Write-Host " [ERROR] Invalid choice. Please select a valid number from the menu." -ForegroundColor Red
        Write-Host " Press any key to try again..."                                       -ForegroundColor DarkGray
        $null = [Console]::ReadKey($true)
    }
    else {
        $success = Switch-PhpVersion -target $selected
        if ($success) {
            $running = $false
            pause
        }
        else {
            # Failure (e.g. folder not found) — let user try again
            Write-Host " Press any key to return to menu..." -ForegroundColor DarkGray
            $null = [Console]::ReadKey($true)
        }
    }
}
