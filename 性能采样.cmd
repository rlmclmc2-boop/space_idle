@echo off
chcp 65001 >nul
setlocal
set "GAME_ROOT=%~dp0space-battleship"
set "GAME_ENGINE=%GAME_ROOT%\engine\Godot_v4.7.2-stable_win64.exe"
set "APPDATA=%GAME_ROOT%\.userdata\roaming"
set "LOCALAPPDATA=%GAME_ROOT%\.userdata\local"
if not exist "%GAME_ENGINE%" (
 echo 找不到引擎：%GAME_ENGINE%
 pause
 exit /b 1
)
if not exist "%GAME_ROOT%\.godot\global_script_class_cache.cfg" (
 echo 请先用 启动.cmd 完成首次资源导入，再关闭游戏运行本采样器。
 pause
 exit /b 1
)
if not exist "%GAME_ROOT%\.runtime" mkdir "%GAME_ROOT%\.runtime"
echo 请先关闭其他游戏实例。进入目标页，关闭弹窗，保持 1 倍速和 +1。
echo 自动记录 20 秒；完成后可按 F7 再记录另一页。关闭游戏后提交 .runtime 中的 frame-sample JSON 和 frame-sample.log。
echo 本入口使用正常存档、定时保存、帧率和画面设置，不会自动切页或改变战斗速度。
start "Space Battleship Performance Sample" "%GAME_ENGINE%" --path "%GAME_ROOT%" --script res://dev/diagnostics/frame_sample.gd --log-file "%GAME_ROOT%\.runtime\frame-sample.log"
