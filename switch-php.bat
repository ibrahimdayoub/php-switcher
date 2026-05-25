@echo off
title PHP Version Switcher

:: ====================================================
:: SELF-ELEVATION CHECK
:: ====================================================
:: The PowerShell script requires Administrator privileges to create
:: junctions and modify Apache config files. If we're not already
:: admin, relaunch this batch file as admin via PowerShell.
::
:: net session returns errorlevel 0 only if running as admin.
:: Start-Process with -Verb RunAs triggers the UAC prompt.
:: ====================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Now running as Administrator — launch the PowerShell script
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0switch-php.ps1"

:: Pause so the window doesn't close immediately when double-clicked
echo.
echo Press any key to exit...
pause >nul
