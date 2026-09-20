# Windows PowerShell 5.1; no Python, SDK, or third-party module required.
[CmdletBinding()]
param()
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
    foreach ($dataFile in @('game_data.json','ui_text.json','ui_text_contract.json')) {
        Copy-Item -LiteralPath (Join-Path $project "data/$dataFile") -Destination (Join-Path $staging 'data')
    }
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
    Stage 'Verify single executable structure'
    $files = @(Get-ChildItem -LiteralPath $candidateDir -Force)
    if ($files.Count -ne 1 -or $files[0].Name -ne 'SpaceBattleship.exe') { throw "Export produced unexpected files in $candidateDir" }
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
    Stage 'Run release verification in isolated user directory'
    $null = Run $verifier @('--','--capture','--capture-all') (Join-Path $run 'empty-cwd') 'verify-runtime' 30 -isolated
    $reportPath = Join-Path $run 'user/roaming/SpaceBattleship/release-verification.json'
    if (!(Test-Path -LiteralPath $reportPath)) { throw "Runtime verification did not complete: $reportPath" }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (!$report.passed) { throw "Runtime checks failed: $reportPath`r`n$($report | ConvertTo-Json -Depth 5)" }
    Stage 'Launch normal game entry point'
    Remove-Work $verifyDir
    $savePath = Join-Path $run 'user/roaming/SpaceBattleship/progress.json'
    Remove-Item -LiteralPath (Assert-InWork $savePath)
    $frames = Join-Path $run 'final-exe-frames'
    New-Item -ItemType Directory -Path $frames | Out-Null
    $null = Run $candidate @('--write-movie',(Join-Path $frames 'frame.png'),'--fixed-fps','30','--quit-after','3') (Join-Path $run 'empty-cwd') 'normal-launch' 60 -isolated
    if (!(Test-Path -LiteralPath $savePath) -or @(Get-ChildItem -LiteralPath $frames -Filter '*.png').Count -eq 0) {
        throw "Final EXE failed to create its own save or rendered frames: $savePath ; $frames"
    }
    $null = Run $candidate @('--quit-after','90') (Join-Path $run 'empty-cwd') 'normal-relaunch' 60 -isolated
    Stage 'Publish verified release'
    $hashStream = [IO.File]::OpenRead($candidate)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $digest = [BitConverter]::ToString($sha256.ComputeHash($hashStream)).Replace('-','') }
    finally { $sha256.Dispose(); $hashStream.Dispose() }
    # Publish via one directory rename only after every gate succeeds.
    $safeCandidate = Assert-InWork $candidateDir
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
    Note "SUCCESS: $(Join-Path $release 'SpaceBattleship.exe')"
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
            foreach ($folder in @('candidate','verification')) {
                try { Remove-Work (Join-Path $run $folder) }
                catch { Note "Cleanup error (isolated outside release): $($_.Exception.Message)" }
            }
        }
    }
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
exit 0
