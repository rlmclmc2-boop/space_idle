param(
    [string]$BuildRoot = $env:SPACE_IDLE_BUILD_ROOT,
    [string]$Godot = $env:SPACE_IDLE_GODOT,
    [string]$Python = $env:SPACE_IDLE_PYTHON
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Python)) { $Python = 'python' }
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'space_idle\build'
}
if ([string]::IsNullOrWhiteSpace($Godot)) { $Godot = 'godot' }
$null = Get-Command $Godot -ErrorAction Stop
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.stable\.') { throw 'Requires Godot 4.7.2 stable.' }
$extension = Join-Path $BuildRoot 'native-stable\space_native.gdextension'
if (-not (Test-Path -LiteralPath $extension)) { throw 'Build addons/native_battle/build_native.ps1 first.' }
$extension = (Resolve-Path -LiteralPath $extension).ProviderPath
& $Python (Join-Path $PSScriptRoot 'foundation\import_excel.py')
if ($LASTEXITCODE -ne 0) { throw 'Excel import failed.' }
$previousExtension = $env:SPACE_IDLE_NATIVE_EXTENSION
try {
    $env:SPACE_IDLE_NATIVE_EXTENSION = $extension
    & $Godot --path $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
} finally {
    $env:SPACE_IDLE_NATIVE_EXTENSION = $previousExtension
}
