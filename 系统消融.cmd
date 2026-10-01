@echo off
chcp 65001 >nul
setlocal
set "GAME_ROOT=%~dp0space-battleship"
set "GAME_ENGINE=%GAME_ROOT%\engine\Godot_v4.7.2-stable_win64.exe"
set "PERF_OFF=%~1"
if /i "%PERF_OFF%"=="control" set "PERF_OFF="
if not exist "%GAME_ENGINE%" (
 echo 找不到引擎：%GAME_ENGINE%
 pause
 exit /b 1
)
if not exist "%GAME_ROOT%\.godot\global_script_class_cache.cfg" (
 echo 请先用 启动.cmd 完成资源导入，再关闭游戏。
 pause
 exit /b 1
)
set "APPDATA=%GAME_ROOT%\.runtime\ablation-user\roaming"
set "LOCALAPPDATA=%GAME_ROOT%\.runtime\ablation-user\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
echo 六秒单变量诊断，使用固定合成初态，1 倍速 / +1。不会读取或写入玩家存档。
echo 不带参数为全系统对照。其他参数：3d / vfx / ui / enhancement / combat。
echo 请先关闭其他游戏实例；对照和单项应使用相同窗口、帧率及画面设置。
echo 当前关闭项：[%PERF_OFF%]。结果位于 space-battleship\.runtime\ablation-*.json。
start "Space Battleship Ablation" /wait "%GAME_ENGINE%" --path "%GAME_ROOT%" --script "%~dp0test\one_times_ablation.gd" --log-file "%GAME_ROOT%\.runtime\ablation-last.log"
exit /b %errorlevel%
