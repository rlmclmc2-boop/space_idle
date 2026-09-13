@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "APPDATA=%~dp0.userdata\roaming"
set "LOCALAPPDATA=%~dp0.userdata\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "Godot Editor" "engine\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0."
