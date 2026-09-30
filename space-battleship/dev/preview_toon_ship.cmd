@echo off
rem Set GODOT to a Godot 4 executable, or install godot on PATH.
python "%~dp0toon_ship\preview.py" --fixture Heavy_Battleship --interactive %*
if errorlevel 1 pause
