@echo off
chcp 65001 >nul
title PrivacyGuard 停止
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-PrivacyGuard.ps1"
pause
