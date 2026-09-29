@echo off
cd /d "%~dp0"
start "" "%~dp0runtime\analyzer.exe" --path "%~dp0." -- %*
