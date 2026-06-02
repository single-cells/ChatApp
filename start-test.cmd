@echo off
REM 双击或在 cmd 中运行：一键启动 API + Flutter
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-test.ps1" %*
if errorlevel 1 exit /b %errorlevel%
