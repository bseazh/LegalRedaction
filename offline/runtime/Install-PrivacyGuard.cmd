@echo off
chcp 65001 >nul
title PrivacyGuard 安装向导
cd /d "%~dp0"
echo 正在安装 PrivacyGuard，请勿关闭窗口。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Offline-Windows.ps1" -InstallPython
if errorlevel 1 goto failed
echo.
echo 安装成功。现在可以双击 Launch-PrivacyGuard.cmd 启动。
pause
exit /b 0
:failed
echo.
echo 安装失败。请保留本窗口内容和 logs 文件夹，再交给安装 Agent 排查。
pause
exit /b 1
