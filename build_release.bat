@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0space-battleship\tools\build_release.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Build stopped. See build.log for the stage, error and paths.
if /I not "%~1"=="--no-pause" pause
exit /b %RESULT%
