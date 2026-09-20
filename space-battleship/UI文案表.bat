@echo off
cd /d "%~dp0"
python tools\ui_text_editor.py
if errorlevel 1 pause
