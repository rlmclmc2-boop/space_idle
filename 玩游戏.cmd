@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if errorlevel 1 goto fail
if not exist "tools\play_main.py" goto fail
python --version >nul 2>nul
if not errorlevel 1 goto python_entry
py -3 --version >nul 2>nul
if errorlevel 1 goto fail
py -3 "tools\play_main.py"
goto check
:python_entry
python "tools\play_main.py"
:check
if errorlevel 1 goto fail
exit /b 0
:fail
echo 启动未完成。请保留上方错误信息，并从正式项目根目录的本入口启动。
pause
exit /b 1
