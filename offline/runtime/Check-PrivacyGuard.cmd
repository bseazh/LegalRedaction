@echo off
chcp 65001 >nul
title PrivacyGuard 状态检测
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-PrivacyGuard.ps1"
pause
