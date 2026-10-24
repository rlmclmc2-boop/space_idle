param(
    [string]$BuildRoot = 'D:\CodexBuild\space_idle',
    [string]$Godot = 'D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$extension = Join-Path $BuildRoot 'native-stable\space_native.gdextension'
if (-not (Test-Path -LiteralPath $extension)) { throw 'Build addons/native_battle/build_native.ps1 first.' }
$extension = (Resolve-Path -LiteralPath $extension).ProviderPath
& $Python (Join-Path $PSScriptRoot 'foundation\import_excel.py')
if ($LASTEXITCODE -ne 0) { throw 'Excel import failed.' }
$previousExtension = $env:SPACE_IDLE_NATIVE_EXTENSION
try {
    $env:SPACE_IDLE_NATIVE_EXTENSION = $extension
    & $Godot --path $PSScriptRoot
} finally {
    $env:SPACE_IDLE_NATIVE_EXTENSION = $previousExtension
}
