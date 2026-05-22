<#
.SYNOPSIS
    PHP Version Switcher for XAMPP (Laravel Optimized)
.DESCRIPTION
    Switches the PHP version symlink in XAMPP to match your Laravel project requirements.
    Each PHP version shows its compatible Laravel range for easy selection.
.NOTES
    Author    : Ibrahim Dayoub
    Requires  : Windows (PowerShell 5.1+), Administrator privileges, XAMPP installed
#>

#Requires -RunAsAdministrator

# ============================================================================
# CONFIGURATION
# ============================================================================
# Add new PHP versions here. Extend the array with more entries as needed.
#   - Id      : menu selection number
#   - Label   : display name
#   - Folder  : XAMPP subdirectory name (e.g., "php74", "php82")
#   - MinLaravel / MaxLaravel : compatible Laravel version range (informational)
# ============================================================================
$phpVersions = @(
    @{ Id = 1; Label = "PHP 7.4"; Folder = "php74"; MinLaravel = "6.x";  MaxLaravel = "8.x"   },
    @{ Id = 2; Label = "PHP 8.0"; Folder = "php80"; MinLaravel = "8.x";  MaxLaravel = "9.x"   },
    @{ Id = 3; Label = "PHP 8.1"; Folder = "php81"; MinLaravel = "9.x";  MaxLaravel = "10.x"  },
    @{ Id = 4; Label = "PHP 8.2"; Folder = "php82"; MinLaravel = "10.x"; MaxLaravel = "11.x"  },
    @{ Id = 5; Label = "PHP 8.3"; Folder = "php83"; MinLaravel = "11.x"; MaxLaravel = "12.x"  }
)

$xamppDir       = "C:\xampp"
$phpSymlinkPath = Join-Path -Path $xamppDir -ChildPath "php"

# ============================================================================
# FUNCTIONS
# ============================================================================

function Show-Header {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "         PHP VERSION SWITCHER FOR XAMPP"              -ForegroundColor Cyan
    Write-Host "             Laravel-Compatible Edition"              -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-CurrentPhpVersion {
    $phpExe = Join-Path -Path $phpSymlinkPath -ChildPath "php.exe"
    if (Test-Path -LiteralPath $phpExe) {
        try {
            $version = & $phpExe -r "echo PHP_VERSION;" 2>$null
            Write-Host " Current PHP Version : " -NoNewline
            Write-Host "$version" -ForegroundColor Green
        } catch {
            Write-Host " Current PHP Version : Unknown (failed to read)" -ForegroundColor Yellow
        }
    } else {
        Write-Host " Current PHP Version : No active PHP link found" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Menu {
    Write-Host " Available PHP Versions:" -ForegroundColor White
    Write-Host "----------------------------" -ForegroundColor DarkGray
    foreach ($v in $phpVersions) {
        Write-Host (" [{0}] {1,-8}  (Laravel {2} - {3})" -f $v.Id, $v.Label, $v.MinLaravel, $v.MaxLaravel)
    }
    Write-Host ""
    Write-Host " [0] Exit" -ForegroundColor Red
    Write-Host ""
}

function Get-UserChoice {
    $choice = Read-Host "Enter choice number"
    if ($choice -eq "0") {
        Write-Host "Exiting. No changes made." -ForegroundColor Yellow
        exit 0
    }
    $selection = $phpVersions | Where-Object { $_.Id -eq [int]$choice }
    return $selection
}

function Switch-PhpVersion {
    param($target)

    $targetFolder = Join-Path -Path $xamppDir -ChildPath $target.Folder

    if (-not (Test-Path -LiteralPath $targetFolder)) {
        Write-Host "[ERROR] Folder '$targetFolder' does not exist!" -ForegroundColor Red
        Write-Host "        Make sure '$($target.Folder)' is present inside $xamppDir" -ForegroundColor Yellow
        return $false
    }

    # Remove existing php symlink / folder
    # if (Test-Path -LiteralPath $phpSymlinkPath) {
    #     $isSymlink = (Get-Item -LiteralPath $phpSymlinkPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint
    #     if ($isSymlink) {
    #         Remove-Item -LiteralPath $phpSymlinkPath -Force
    #     } else {
    #         Remove-Item -LiteralPath $phpSymlinkPath -Recurse -Force
    #     }
    # }

    if (Test-Path -LiteralPath $phpSymlinkPath) {
        $isSymlink = (Get-Item -LiteralPath $phpSymlinkPath).Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ($isSymlink) {
            Remove-Item -LiteralPath $phpSymlinkPath -Force
        } else {
            # Safety Measure: Rename real folder instead of breaking it permanently
            $backupPath = "$phpSymlinkPath" + "_backup_" + (Get-Date -Format "yyyyMMddHHmmss")
            Rename-Item -Path $phpSymlinkPath -NewName $backupPath -Force
            Write-Host "[WARNING] Existing 'php' was a real folder. Renamed to '$backupPath' for safety." -ForegroundColor Yellow
        }
    }

    # Create new directory junction (symlink)
    New-Item -ItemType Junction -Path $phpSymlinkPath -Target $targetFolder | Out-Null

    Write-Host ""
    Write-Host "[SUCCESS] Switched to $($target.Label)" -ForegroundColor Green
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " Compatible Laravel : $($target.MinLaravel) - $($target.MaxLaravel)" -ForegroundColor White
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " IMPORTANT: Restart your terminal / VS Code" -ForegroundColor Yellow
    Write-Host "            to apply the changes." -ForegroundColor Yellow
    Write-Host ""

    return $true
}

# ============================================================================
# XAMPP EXISTENCE CHECK
# ============================================================================

if (-not (Test-Path -LiteralPath $xamppDir)) {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host "      XAMPP NOT FOUND!"                               -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host " XAMPP is not installed at: $xamppDir"                -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Please install XAMPP on drive C: first."              -ForegroundColor White
    Write-Host " Download from: https://www.apachefriends.org/"        -ForegroundColor Cyan
    Write-Host ""
    Write-Host " After installation, run this script again."           -ForegroundColor White
    Write-Host ""
    pause
    exit 1
}

# ============================================================================
# MAIN
# ============================================================================

Show-Header
Get-CurrentPhpVersion
Show-Menu

$selected = Get-UserChoice

if (-not $selected) {
    Write-Host "[ERROR] Invalid choice. Please run the script again." -ForegroundColor Red
    pause
    exit 1
}

Switch-PhpVersion -target $selected

pause