@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "EDITOR_ENGINE=%SPACE_BATTLESHIP_GODOT%"
if not defined EDITOR_ENGINE for %%G in ("%~dp0engine\Godot*_win64.exe") do set "EDITOR_ENGINE=%%~fG"
if not exist "%EDITOR_ENGINE%" (
  echo 未找到 Godot，请将 Windows 引擎放入 engine 目录，或设置 SPACE_BATTLESHIP_GODOT。
  pause
  exit /b 1
)
if not exist ".runtime" mkdir ".runtime"
set "APPDATA=%~dp0.runtime\level-editor-user\roaming"
set "LOCALAPPDATA=%~dp0.runtime\level-editor-user\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
"%EDITOR_ENGINE%" --headless --editor --import --quit --path "%~dp0." --log-file "%~dp0.runtime\level-editor-import.log"
if errorlevel 1 (
  echo 资源导入失败，请查看 .runtime\level-editor-import.log
  pause
  exit /b 1
)
start "Level Editor" "%EDITOR_ENGINE%" --path "%~dp0." res://level_editor.tscn