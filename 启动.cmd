@echo off
chcp 65001 >nul
setlocal
set "GAME_ROOT=%~dp0space-battleship"
set "GAME_ENGINE=%GAME_ROOT%\engine\Godot_v4.7.2-stable_win64.exe"
cd /d "%GAME_ROOT%"
set "APPDATA=%GAME_ROOT%\.userdata\roaming"
set "LOCALAPPDATA=%GAME_ROOT%\.userdata\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%GAME_ROOT%\.runtime" mkdir "%GAME_ROOT%\.runtime"
if not exist "%GAME_ENGINE%" (
    echo 找不到游戏引擎：%GAME_ENGINE%
    pause
    exit /b 1
)
echo 正在准备游戏资源，请稍候...
start "Import Game Resources" /wait "%GAME_ENGINE%" --headless --editor --import --quit --path "%GAME_ROOT%" --log-file "%GAME_ROOT%\.runtime\startup-import.log"
if errorlevel 1 (
    echo 游戏资源准备失败，请查看 space-battleship\.runtime\startup-import.log
    pause
    exit /b 1
)
start "Space Battleship" "%GAME_ENGINE%" --path "%GAME_ROOT%"
