@echo off
title PHP Version Switcher

:: Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process powershell '-ExecutionPolicy Bypass -File \"%~dp0switch-php.ps1\"' -Verb RunAs"
    exit /b
)

:: Launch the PowerShell script directly if already admin
powershell -ExecutionPolicy Bypass -File "%~dp0switch-php.ps1"