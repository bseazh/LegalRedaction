@echo off
chcp 65001 >nul
title PrivacyGuard 一键启动
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PrivacyGuard.ps1"
if errorlevel 1 echo 启动未完成，请双击 Check-PrivacyGuard.cmd 查看状态。
pause
