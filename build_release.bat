@echo off
setlocal DisableDelayedExpansion
set "RELEASE_LAUNCH_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { try { $base=$env:RELEASE_LAUNCH_ROOT; $folders=@(Get-Item -LiteralPath $base) + @(Get-ChildItem -LiteralPath $base -Directory); $projects=@($folders | Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'tools/build_release.ps1')) }); if ($projects.Count -ne 1) { throw ('Expected exactly one Godot project beside this launcher; found ' + $projects.Count + '. Launcher directory: ' + $base) }; & (Join-Path $projects[0].FullName 'tools/build_release.ps1'); exit $LASTEXITCODE } catch { $message='FAILED STAGE: Locate project' + [Environment]::NewLine + $_.Exception.Message; [Console]::Error.WriteLine($message); [IO.File]::WriteAllText((Join-Path $env:RELEASE_LAUNCH_ROOT 'build.log'),$message); exit 1 } }"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo Build stopped. See build.log beside the launcher for the stage, error and paths.
if /I not "%~1"=="--no-pause" pause
exit /b %RESULT%
