# Windows PowerShell 5.1; no Python, SDK, or third-party module required.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory=$true)][string]$NativeBuildManifest
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Directory]::GetParent($project).FullName
$workRoot = Join-Path $root 'test/work'
$release = Join-Path $root 'release'
$log = Join-Path $root 'build.log'
$stage = 'Initialize'
$lock = $null
$run = $null
$published = $false
$utf8 = New-Object Text.UTF8Encoding($false)

function Note([string]$message) {
    Write-Host $message
    [IO.File]::AppendAllText($log, "$message`r`n", $utf8)
}
function Stage([string]$name) { $script:stage = $name; Note "`r`n[$name]" }
function Assert-InWork([string]$path) {
    $resolved = [IO.Path]::GetFullPath($path)
    if (!$resolved.StartsWith($workRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing filesystem operation outside build work directory: $resolved"
    }
    return $resolved
}
function Remove-Work([string]$path) {
    $safe = Assert-InWork $path
    # Windows may briefly retain an executable mapping after process exit.
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            if (Test-Path -LiteralPath $safe) { Remove-Item -LiteralPath $safe -Force -Recurse }
            return
        } catch {
            if ($attempt -eq 19) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
}
function Run([string]$exe, [string[]]$arguments, [string]$cwd, [string]$name, [int]$timeout = 300, [switch]$isolated) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $exe
    $info.Arguments = ($arguments | ForEach-Object {
        if ($_ -match '"') { throw "Unsupported quote in argument: $_" }
        '"' + $_ + '"'
    }) -join ' '
    $info.WorkingDirectory = $cwd
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    if ($isolated) {
        $info.EnvironmentVariables.Clear()
        foreach ($key in @('SystemRoot','WINDIR','SystemDrive','COMSPEC','USERNAME','USERDOMAIN','ProgramData','ALLUSERSPROFILE','PUBLIC','ProgramFiles','ProgramFiles(x86)','ProgramW6432','CommonProgramFiles','CommonProgramFiles(x86)','CommonProgramW6432')) {
            $value = [Environment]::GetEnvironmentVariable($key)
            if ($value) { $info.EnvironmentVariables[$key] = $value }
        }
        $info.EnvironmentVariables['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot"
        $info.EnvironmentVariables['APPDATA'] = Join-Path $run 'user/roaming'
        $info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $run 'user/local'
        $info.EnvironmentVariables['USERPROFILE'] = Join-Path $run 'user'
        $info.EnvironmentVariables['TEMP'] = Join-Path $run 'user/temp'
        $info.EnvironmentVariables['TMP'] = Join-Path $run 'user/temp'
    }
    Note "Command: $exe $($info.Arguments)"
    Note "Working directory: $cwd"
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        if (!$process.Start()) { throw "Could not start $exe" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $finished = $process.WaitForExit($timeout * 1000)
        if (!$finished) { $process.Kill(); $process.WaitForExit() }
        $output = $stdout.Result + "`r`n" + $stderr.Result
        $outputPath = Join-Path $run ($name + '.log')
        [IO.File]::WriteAllText($outputPath, $output, $utf8)
        [IO.File]::AppendAllText($log, $output, $utf8)
        Note "Process log: $outputPath"
        if (!$finished) { throw "Timeout after ${timeout}s: $exe. See $outputPath" }
        if ($process.ExitCode -ne 0 -or $output -match '(?im)(SCRIPT ERROR:|(^|\s)ERROR:|Parse Error|Failed to load)') {
            throw "Exit code $($process.ExitCode): $exe`r`n$output"
        }
        return $output
    } finally { $process.Dispose() }
}

try {
    New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
    $lock = [IO.File]::Open((Join-Path $workRoot 'release-build.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    [IO.File]::WriteAllText($log, "Space Battleship release build $(Get-Date -Format o)`r`n", $utf8)
    Stage 'Locate project'
    Note "Detected project: $project"
    Note "Workspace / output root: $root"
    if (!(Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) {
        throw "Godot project missing beside tools directory: $project. Keep tools inside the project folder."
    }
    $run = Join-Path $workRoot ('release-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $run | Out-Null
    Stage 'Verify pinned source and native build'
    $head = (& git -C $root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -ne $ExpectedSourceCommit) { throw 'Unexpected source commit' }
    & git -C $root diff --exit-code $ExpectedSourceCommit -- space-battleship test/verify_release.gd
    if ($LASTEXITCODE -ne 0) { throw 'Release source differs from pinned commit' }
    $nativeBuild = Get-Content -LiteralPath $NativeBuildManifest -Raw | ConvertFrom-Json
    if ($nativeBuild.build_exit -ne 0 -or $nativeBuild.dll_sha256 -notmatch '^[0-9a-f]{64}$') { throw 'Invalid native build manifest' }
    foreach ($name in @('space_native.cpp','combat_execution_kernel.h','combat_presentation.h')) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $project ('addons/native_battle/src/' + $name)) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $nativeBuild.source_sha256.$name) { throw "Native source differs from verified build: $name" }
    }
    $nativeHash = (Get-FileHash -LiteralPath (Join-Path $project 'bin/space_native.dll') -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($nativeHash -ne $nativeBuild.dll_sha256) { throw 'Native DLL differs from verified build' }
    Note "Pinned source: $head; native DLL SHA256: $nativeHash"
    Stage 'Clean / quarantine previous release'
    if (Test-Path -LiteralPath $release) {
        $previous = Assert-InWork (Join-Path $run 'previous-release-not-current')
        # Both absolute endpoints are fixed inside this workspace; never delete a player's directory.
        if ([IO.Path]::GetFullPath($release) -ne (Join-Path $root 'release')) { throw 'Invalid release path' }
        Move-Item -LiteralPath $release -Destination $previous
        Note "Previous output isolated: $previous"
    }
    Stage 'Check build tools'
    $engine = Join-Path $project 'engine/Godot_v4.7.2-stable_win64.exe'
    $template = Join-Path $project 'engine/templates/4.7.2.stable/windows_release_x86_64.exe'
    foreach ($required in @($engine, $template, (Join-Path $project 'assets/fonts/NotoSansSC.ttf'), (Join-Path $project 'assets/fonts/OFL.txt'))) {
        if (!(Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Missing required file: $required. See $(Join-Path $project 'README.md') (Windows release): install official Godot 4.7.2 editor and matching standard export template; restore the bundled OFL font. No fallback build is produced."
        }
    }
    $version = Run $engine @('--version') $run 'version'
    if ($version.Trim() -ne '4.7.2.stable.official.ed1daf0bf') { throw "Unexpected editor version: $version" }
    Stage 'Stage runtime inputs'
    $staging = Join-Path $run 'project'
    $candidateDir = Join-Path $run 'candidate'
    foreach ($dir in @($staging, $candidateDir, (Join-Path $run 'empty-cwd'), (Join-Path $run 'user/roaming'), (Join-Path $run 'user/local'), (Join-Path $run 'user/temp'))) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    foreach ($folder in @('Desktop','Documents','Downloads','Music','Pictures','Videos')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $run ('user/' + $folder)) | Out-Null
    }
    foreach ($file in @('project.godot','main.tscn')) { Copy-Item -LiteralPath (Join-Path $project $file) -Destination $staging }
    foreach ($folder in @('scripts','assets')) { Copy-Item -LiteralPath (Join-Path $project $folder) -Destination $staging -Recurse }
    New-Item -ItemType Directory -Path (Join-Path $staging 'data') | Out-Null
    foreach ($dataFile in @('game_data.json','ui_text.json','ui_text_contract.json','ship_weapon_visuals.json','hyperspace_config.json','hyperspace_entity_schema.json','hyperspace_visuals.json','space_enemy_candidates.json','space_enemy_reward_catalog.json','space_enemy_reward_recipes.json','space_enemy_reward_sources.json','space_enemy_routes.json')) {
        Copy-Item -LiteralPath (Join-Path $project "data/$dataFile") -Destination (Join-Path $staging 'data')
    }
    # Only runtime extension metadata/binary and the presentation resources it uses.
    foreach ($relative in @('addons/native_battle/space_native.gdextension','bin/space_native.dll','addons/flexible_toon_shader/flexible_toon.gdshader','addons/flexible_toon_shader/LICENSE','dev/toon_ship/chain_vfx.gd','dev/toon_ship/missile_vfx.gd','dev/toon_ship/continuous_beam_vfx.gd','dev/toon_ship/rail_vfx.gd','dev/toon_ship/pulse_vfx.gd','dev/toon_ship/hybrid_layout.gd','dev/toon_ship/hybrid_manifest.json','dev/toon_ship/shield.gdshader','dev/toon_ship/exhaust.gdshader')) {
        $destination = Join-Path $staging $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $project $relative) -Destination $destination
    }
    foreach ($folder in @('hulls','weapons')) {
        $destination = Join-Path $staging ('dev/toon_ship/' + $folder)
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $project ('dev/toon_ship/' + $folder)) -File | Where-Object { $_.Extension -in @('.glb','.tscn') }) {
            Copy-Item -LiteralPath $file.FullName -Destination $destination
        }
    }
    if ((Get-FileHash -LiteralPath (Join-Path $staging 'bin/space_native.dll') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $nativeHash) { throw 'Staged native DLL mismatch' }
    $presetPath = Join-Path $project 'export_presets.cfg'
    $preset = [IO.File]::ReadAllText($presetPath)
    $templateSetting = '(?m)^custom_template/release\s*=\s*[^\r\n]*'
    if ([regex]::Matches($preset, $templateSetting).Count -ne 1) {
        throw "Expected one release template setting in $presetPath"
    }
    # Rebind even an old machine's absolute path; never modify the source preset.
    $preset = [regex]::Replace($preset, $templateSetting, [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        'custom_template/release="' + $template.Replace('\','/') + '"'
    })
    [IO.File]::WriteAllText((Join-Path $staging 'export_presets.cfg'), $preset, $utf8)
    Stage 'Import resources / compile scripts'
    $null = Run $engine @('--headless','--path',$staging,'--editor','--import') $run 'import' 300 -isolated
    Stage 'Export release / embed PCK'
    $candidate = Join-Path $candidateDir 'SpaceBattleship.exe'
    $null = Run $engine @('--headless','--path',$staging,'--export-release','Windows Single EXE',$candidate) $run 'export' 300 -isolated
    Stage 'Verify runtime payload whitelist'
    $files = @(Get-ChildItem -LiteralPath $candidateDir -Recurse -File -Force)
    $allowed = @('SpaceBattleship.exe','space_native.dll','bin/space_native.dll')
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($candidateDir.Length + 1).Replace('\','/')
        if ($relative -notin $allowed) { throw "Unexpected release payload: $relative" }
    }
    $nativeFiles = @($files | Where-Object { $_.Name -eq 'space_native.dll' })
    if ($files.Count -ne 2 -or $nativeFiles.Count -ne 1) { throw "Expected exactly EXE and required native DLL in $candidateDir" }
    if ((Get-FileHash -LiteralPath $nativeFiles[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $nativeHash) { throw 'Exported native DLL differs from validated source DLL' }
    $stream = [IO.File]::OpenRead($candidate)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw "Invalid PE file: $candidate" }
        $stream.Position = 0x3c; $pe = $reader.ReadUInt32()
        $stream.Position = $pe
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw 'Expected Windows x64 PE' }
        $sectionCount = $reader.ReadUInt16()
        $stream.Position = $pe + 20
        $optionalSize = $reader.ReadUInt16()
        $stream.Position = $pe + 24
        if ($reader.ReadUInt16() -ne 0x20b) { throw 'Expected PE32+ executable' }
        $stream.Position = $pe + 24 + 120
        $importRva = $reader.ReadUInt32()
        $sections = @()
        for ($i = 0; $i -lt $sectionCount; $i++) {
            $stream.Position = $pe + 24 + $optionalSize + $i * 40 + 8
            $virtualSize = $reader.ReadUInt32(); $rva = $reader.ReadUInt32()
            $rawSize = $reader.ReadUInt32(); $offset = $reader.ReadUInt32()
            $sections += @{ Rva=$rva; Size=[Math]::Max($virtualSize,$rawSize); Offset=$offset }
        }
        function Rva-Offset([uint32]$rva) {
            foreach ($section in $sections) {
                if ($rva -ge $section.Rva -and $rva -lt ($section.Rva + $section.Size)) {
                    return [long]($section.Offset + $rva - $section.Rva)
                }
            }
            throw "Invalid PE import RVA: $rva"
        }
        $imports = @()
        $importOffset = Rva-Offset $importRva
        for ($i = 0; $i -lt 256; $i++) {
            $stream.Position = $importOffset + $i * 20 + 12
            $nameRva = $reader.ReadUInt32()
            if ($nameRva -eq 0) { break }
            $stream.Position = Rva-Offset $nameRva
            $dll = ''
            while (($byte = $reader.ReadByte()) -ne 0) { $dll += [char]$byte }
            $imports += $dll.ToLowerInvariant()
        }
        $systemDlls = @('kernel32.dll','user32.dll','gdi32.dll','advapi32.dll','shell32.dll','ole32.dll','oleaut32.dll','ws2_32.dll','winmm.dll','imm32.dll','version.dll','setupapi.dll','opengl32.dll','shlwapi.dll','bcrypt.dll','crypt32.dll','dbghelp.dll','dwmapi.dll','winhttp.dll','iphlpapi.dll','ntdll.dll','comdlg32.dll','comctl32.dll','msvcrt.dll','ucrtbase.dll','rpcrt4.dll','avrt.dll','dwrite.dll','dinput8.dll','dxgi.dll','xinput1_4.dll','hid.dll','powrprof.dll','psapi.dll','userenv.dll','normaliz.dll','secur32.dll','wtsapi32.dll','d3d9.dll','d3d11.dll','d3d12.dll')
        $systemDlls += @('uiautomationcore.dll','shcore.dll','wsock32.dll')
        Note "PE imports: $($imports -join ', ')"
        foreach ($dll in $imports) {
            if ($dll -notin $systemDlls -and $dll -notlike 'api-ms-win-*.dll') { throw "Unexpected external runtime dependency: $dll" }
        }
        Note "PE imports (Windows system libraries only): $($imports -join ', ')"
        $stream.Position = $pe + 24 + 68
        if ($reader.ReadUInt16() -ne 2) { throw 'Expected GUI subsystem (no console)' }
        $stream.Position = $stream.Length - 4
        if ($reader.ReadUInt32() -ne 0x43504447) { throw 'Embedded Godot PCK footer missing' }
    } finally { $reader.Dispose(); $stream.Dispose() }
    Stage 'Build separate release verifier (no test entry in final EXE)'
    $probe = Join-Path $staging 'verify_release.gd'
    Copy-Item -LiteralPath (Join-Path $root 'test/verify_release.gd') -Destination $probe
    [IO.File]::WriteAllText((Join-Path $staging 'verify_release.tscn'), "[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://verify_release.gd`" id=`"1`"]`n[node name=`"ReleaseVerifier`" type=`"Node`"]`nscript = ExtResource(`"1`")`n", $utf8)
    $settings = [IO.File]::ReadAllText((Join-Path $staging 'project.godot')).Replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://verify_release.tscn"')
    [IO.File]::WriteAllText((Join-Path $staging 'project.godot'), $settings, $utf8)
    $verifyDir = Join-Path $run 'verification'
    New-Item -ItemType Directory -Path $verifyDir | Out-Null
    $verifier = Join-Path $verifyDir 'Verify.exe'
    $null = Run $engine @('--headless','--path',$staging,'--editor','--import') $run 'verify-import' 300 -isolated
    $null = Run $engine @('--headless','--path',$staging,'--export-release','Windows Single EXE',$verifier) $run 'verify-export' 300 -isolated
    Stage 'Remove intermediate project before independent launch'
    Remove-Work $staging
    Stage 'Create ZIP and independently unpack runtime'
    $publishDir = Join-Path $run 'publish'
    $unpacked = Join-Path $run 'zip-runtime'
    New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
    $zipPath = Join-Path $publishDir 'SpaceBattleship.zip'
    Compress-Archive -Path (Join-Path $candidateDir '*') -DestinationPath $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $unpacked
    $candidate = Join-Path $unpacked 'SpaceBattleship.exe'
    $zipNative = Join-Path $unpacked ($nativeFiles[0].FullName.Substring($candidateDir.Length + 1))
    if ((Get-FileHash -LiteralPath $zipNative -Algorithm SHA256).Hash.ToLowerInvariant() -ne $nativeHash) { throw 'ZIP native DLL mismatch' }
    Stage 'Run release verification in isolated user directory'
    $null = Run $verifier @('--max-fps','0','--disable-vsync','--','--capture','--capture-all') (Join-Path $run 'empty-cwd') 'verify-runtime' 30 -isolated
    $reportPath = Join-Path $run 'user/roaming/SpaceBattleship/release-verification.json'
    if (!(Test-Path -LiteralPath $reportPath)) { throw "Runtime verification did not complete: $reportPath" }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($report.native_sha256 -ne $nativeHash -or !$report.native_admitted) { throw 'Release native DLL/kernel proof failed' }
    if (!$report.passed) { throw "Runtime checks failed: $reportPath`r`n$($report | ConvertTo-Json -Depth 5)" }
    Stage 'Launch normal game entry point'
    Remove-Work $verifyDir
    $savePath = Join-Path $run 'user/roaming/SpaceBattleship/progress.json'
    # The verifier proved an explicit save. Normal launch must load it; the
    # product saves only on its real-time deadline or an explicit user action.
    if (!(Test-Path -LiteralPath $savePath)) { throw 'Verified explicit save missing before normal launch' }
    $finalScreenshot = Join-Path $run 'user/roaming/SpaceBattleship/release-launch.png'
    $null = Run $candidate @('--max-fps','0','--disable-vsync','--verbose','--quit-after','90','--','--release-screenshot') (Join-Path $run 'empty-cwd') 'normal-launch' 60 -isolated
    if (!(Test-Path -LiteralPath $finalScreenshot -PathType Leaf) -or (Get-Item -LiteralPath $finalScreenshot).Length -eq 0) {
        throw "Final ZIP executable failed to capture its rendered viewport: $finalScreenshot"
    }
    Note "Native admission evidence: independent verifier; final ZIP executable evidence: normal startup and rendered viewport $finalScreenshot"
    Stage 'Publish verified release'
    $hashStream = [IO.File]::OpenRead($zipPath)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $digest = [BitConverter]::ToString($sha256.ComputeHash($hashStream)).Replace('-','') }
    finally { $sha256.Dispose(); $hashStream.Dispose() }
    # Publish via one directory rename only after every gate succeeds.
    $safeCandidate = Assert-InWork $publishDir
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try { [IO.Directory]::Move($safeCandidate, $release); break }
        catch {
            if ($attempt -eq 19) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
    $published = $true
    Note "SHA256: $digest"
    Note "Verification report/screenshot: $(Split-Path $reportPath)"
    Note "Build log: $log"
    Note "SUCCESS: $(Join-Path $release 'SpaceBattleship.zip')"
} catch {
    $failure = "FAILED STAGE: $stage`r`n$($_.Exception.Message)`r`nLocation: $($_.InvocationInfo.PositionMessage)`r`nBuild log: $log`r`nWork directory: $run"
    Write-Host $failure -ForegroundColor Red
    if ($lock) {
        [IO.File]::AppendAllText($log, $failure, $utf8)
        if ($published -and (Test-Path -LiteralPath $release)) {
            Move-Item -LiteralPath $release -Destination (Assert-InWork (Join-Path $run 'failed-publish-not-current'))
        }
        # Candidate is never a release; remove it on any failed gate.
        if ($run) {
            foreach ($folder in @('candidate','verification','publish','zip-runtime')) {
                try { Remove-Work (Join-Path $run $folder) }
                catch { Note "Cleanup error (isolated outside release): $($_.Exception.Message)" }
            }
        }
    }
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
exit 0
