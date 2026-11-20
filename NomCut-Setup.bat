@echo off
setlocal
title NomCut Studio Setup
echo.
echo   Starting NomCut Studio installer (internet connection required)...
echo   This launcher fetches and executes install.ps1. You can inspect it in Notepad anytime.
echo.
set "F=%~dp0install.ps1"
if exist "%F%" goto :run
set "U=https://raw.githubusercontent.com/StingLikeABeee/NomCut/main/install.ps1"
set "F=%TEMP%\nomcut-install.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing '%U%' -OutFile '%F%' } catch { Write-Host ('Download failed: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 goto :fail
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%F%"
goto :end
:fail
echo.
echo   Could not download the installer. Check your internet connection and double-click again.
:end
echo.
pause
