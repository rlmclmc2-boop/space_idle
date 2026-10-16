@echo off
chcp 65001 >nul
setlocal
cd /d "D:\放置"
if errorlevel 1 goto fail
if not exist "tools\play_main.py" goto fail
py -3 "D:\放置\tools\play_main.py"
if errorlevel 1 goto fail
exit /b 0
:fail
echo 启动未完成。请保留上方错误信息。此入口只运行 D:\放置 中的正式项目。
pause
exit /b 1
