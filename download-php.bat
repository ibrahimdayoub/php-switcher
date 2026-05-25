@echo off
title PHP Downloader for XAMPP

:: ====================================================
:: SELF-ELEVATION CHECK
:: ====================================================
:: Same pattern as switch-php.bat: if not admin, relaunch as admin.
:: The %* passes any command-line arguments through to the new instance,
:: so "download-php 7.4" works from command prompt.
:: ====================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' '%*' -Verb RunAs"
    exit /b
)

:: Now running as Administrator — launch the PowerShell script with any args
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0download-php.ps1" %*

:: Pause so the window doesn't close immediately
echo.
echo Press any key to exit...
pause >nul
