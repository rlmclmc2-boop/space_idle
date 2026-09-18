# Exercise the real entry point with broken inputs in a disposable workspace.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sandbox = Join-Path $PSScriptRoot ('work/release-failure-tests-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
$project = Join-Path $sandbox 'space-battleship'
New-Item -ItemType Directory -Force -Path "$project/tools", "$sandbox/test", "$sandbox/release" | Out-Null
Copy-Item -LiteralPath "$root/build_release.bat" -Destination $sandbox
Copy-Item -LiteralPath "$root/space-battleship/tools/build_release.ps1" -Destination "$project/tools"
Set-Content -LiteralPath "$sandbox/release/OldBuild.exe" -Value 'old build fixture'
$results = @()
function Expect-Failure([string]$name, [string]$stage) {
    & cmd.exe /c "`"$sandbox/build_release.bat`" --no-pause" > "$sandbox/$name.log" 2>&1
    $code = $LASTEXITCODE
    $log = Get-Content -LiteralPath "$sandbox/build.log" -Raw
    if ($code -eq 0 -or $log -notmatch [regex]::Escape("FAILED STAGE: $stage")) {
        throw "Wrong failure result for $name (exit=$code). See $sandbox/$name.log"
    }
    if (Test-Path -LiteralPath "$sandbox/release") { throw "Failed build left release directory: $name" }
    $candidates = @(Get-ChildItem -LiteralPath "$sandbox/test/work" -Recurse -Filter SpaceBattleship.exe)
    if ($candidates.Count -ne 0) { throw "Incomplete candidate survived: $name" }
    $script:results += "$name : PASS (exit=$code, expected stage, no current release or incomplete executable)"
}
Expect-Failure 'missing-tool-and-old-release' 'Check build tools'
$old = @(Get-ChildItem -LiteralPath "$sandbox/test/work" -Recurse -Filter OldBuild.exe)
if ($old.Count -ne 1 -or $old[0].FullName -notmatch 'previous-release-not-current') { throw 'Old output not quarantined' }

foreach ($folder in @('engine/templates/4.7.2.stable','assets/fonts','scripts','data')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $project $folder) | Out-Null
}
# Hardlinks are read-only build inputs here; never modify their shared bytes.
foreach ($relative in @('engine/Godot_v4.7.2-stable_win64.exe','assets/fonts/NotoSansSC.ttf','assets/fonts/OFL.txt')) {
    New-Item -ItemType HardLink -Path (Join-Path $project $relative) -Target (Join-Path "$root/space-battleship" $relative) | Out-Null
}
$template = "$project/engine/templates/4.7.2.stable/windows_release_x86_64.exe"
Copy-Item -LiteralPath "$root/space-battleship/engine/templates/4.7.2.stable/windows_release_x86_64.exe" -Destination $template
Copy-Item -LiteralPath "$root/space-battleship/export_presets.cfg" -Destination $project
Copy-Item -LiteralPath "$root/space-battleship/project.godot" -Destination $project
Copy-Item -LiteralPath "$root/space-battleship/main.tscn" -Destination $project
Set-Content -LiteralPath "$project/data/game_data.json" -Value '{}'
Set-Content -LiteralPath "$project/scripts/main.gd" -Value "extends Node2D`nTHIS IS NOT VALID GDSCRIPT"
Expect-Failure 'script-import-error' 'Import resources / compile scripts'
Set-Content -LiteralPath "$project/scripts/main.gd" -Value 'extends Node2D'
Set-Content -LiteralPath $template -Value 'not a PE template'
Expect-Failure 'broken-export-template' 'Export release / embed PCK'
Copy-Item -LiteralPath "$root/space-battleship/engine/templates/4.7.2.stable/windows_release_x86_64.exe" -Destination $template -Force
Set-Content -LiteralPath "$sandbox/test/verify_release.gd" -Value "extends Node`nfunc _ready():`n`tget_tree().quit(23)"
Expect-Failure 'runtime-verification-error' 'Run release verification in isolated user directory'
$results | Set-Content -LiteralPath "$sandbox/results.txt"
$results
Write-Host "Evidence: $sandbox"
