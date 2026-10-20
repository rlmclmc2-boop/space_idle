@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if errorlevel 1 goto fail
if not exist "tools\bootstrap_player.ps1" goto fail
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "tools\bootstrap_player.ps1"
if errorlevel 1 goto fail
exit /b 0
:fail
echo 启动未完成。请保留上方错误信息，并从正式项目根目录的本入口启动。
pause
exit /b 1
