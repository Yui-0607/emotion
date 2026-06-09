@echo off
chcp 65001 >nul
title 见微 · 人生观察者

echo.
echo   正在启动...
echo.

REM 后台启动服务器
start "见微服务器" powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0server\server-proxy.ps1"

REM 等一秒确保服务器就绪
timeout /t 2 /nobreak >nul

REM 打开浏览器
start http://localhost:3000

echo   如果浏览器没有自动打开，请手动访问 http://localhost:3000
echo.
echo   按任意键关闭此窗口...
pause >nul