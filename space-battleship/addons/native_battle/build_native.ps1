param(
    [string]$BuildRoot = $env:SPACE_IDLE_BUILD_ROOT,
    [string]$GodotCpp = $env:SPACE_IDLE_GODOT_CPP,
    [string]$LlvmMingw = $env:SPACE_IDLE_LLVM_MINGW,
    [string]$Api = $env:SPACE_IDLE_GODOT_API,
    [string]$Python = $env:SPACE_IDLE_PYTHON,
    [int]$Jobs = 1
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Python)) { $Python = 'python' }
$required = @{ GodotCpp = @{ value = $GodotCpp; env = 'SPACE_IDLE_GODOT_CPP' };
    LlvmMingw = @{ value = $LlvmMingw; env = 'SPACE_IDLE_LLVM_MINGW' };
    Api = @{ value = $Api; env = 'SPACE_IDLE_GODOT_API' } }
foreach ($name in $required.Keys) {
    if ([string]::IsNullOrWhiteSpace($required[$name].value)) { throw "Supply -$name or $($required[$name].env) to build the native extension." }
}
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'space_idle\build'
}
$buildPath = [IO.Path]::GetFullPath($BuildRoot)
$binding = (Resolve-Path -LiteralPath $GodotCpp).ProviderPath
$compiler = (Resolve-Path -LiteralPath $LlvmMingw).ProviderPath
$apiPath = (Resolve-Path -LiteralPath $Api).ProviderPath
$clang = Join-Path $compiler 'bin\clang++.exe'
if (-not (Test-Path -LiteralPath $clang)) { throw 'LlvmMingw must point to an llvm-mingw installation with bin\clang++.exe.' }
$clangVersion = & $clang --version
if ($LASTEXITCODE -ne 0 -or $clangVersion[0] -notmatch '^clang version 23\.1\.3\b' -or
    ($clangVersion -join "`n") -notmatch 'Target: x86_64-w64-windows-gnu') {
    throw 'Requires the pinned llvm-mingw 20261006 x86_64 toolchain (Clang 23.1.3).'
}
$null = Get-Command $Python -ErrorAction Stop
$null = & $Python -c 'import SCons'
if ($LASTEXITCODE -ne 0) { throw 'Python must have SCons installed.' }
$native = Join-Path $buildPath 'native-stable'
$expectedBinding = '507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'
$bindingHead = & git -c safe.directory='*' -C $binding rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $bindingHead -ne $expectedBinding) { throw 'Requires official godot-cpp 10.0.0-stable at the pinned commit.' }
if ((Get-FileHash -LiteralPath $apiPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986') {
    throw 'API must be the verified single-precision Godot 4.7.2 export.'
}
# Changes to these environment variables exist only inside this build process.
$saved = @{}
foreach ($key in 'TEMP','TMP','PATH','PYTHONPYCACHEPREFIX','PIP_CACHE_DIR') { $saved[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
try {
    $env:TEMP = Join-Path $buildPath 'tmp'; $env:TMP = $env:TEMP
    $env:PYTHONPYCACHEPREFIX = Join-Path $buildPath 'cache\pycache'
    $env:PIP_CACHE_DIR = Join-Path $buildPath 'cache\pip'
    $env:PATH = (Join-Path $compiler 'bin') + ';' + $env:PATH
    New-Item -ItemType Directory -Force -Path $env:TEMP,$env:PYTHONPYCACHEPREFIX,$env:PIP_CACHE_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $native 'src') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SConstruct') -Destination (Join-Path $native 'SConstruct')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\space_native.cpp') -Destination (Join-Path $native 'src\space_native.cpp')
    Copy-Item -Path (Join-Path $PSScriptRoot 'src\*.hpp') -Destination (Join-Path $native 'src') -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\combat_execution_kernel.h') -Destination (Join-Path $native 'src\combat_execution_kernel.h')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\combat_presentation.h') -Destination (Join-Path $native 'src\combat_presentation.h')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\combat_retained_presentation.h') -Destination (Join-Path $native 'src\combat_retained_presentation.h')
    Push-Location $native
    try {
        & $Python -m SCons "bindings=$($binding.Replace('\','/'))" platform=windows arch=x86_64 use_mingw=yes use_llvm=yes "mingw_prefix=$($compiler.Replace('\','/'))" use_static_cpp=yes "custom_api_file=$($apiPath.Replace('\','/'))" target=template_release lto=none -j $Jobs
        if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
    } finally { Pop-Location }
    $nativeDll = Join-Path $native 'bin\space_native.dll'
    $extensionTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'space_native.gdextension.in'))
    $extensionText = $extensionTemplate.Replace('res://bin/space_native.dll', $nativeDll.Replace('\','/'))
    [IO.File]::WriteAllText((Join-Path $native 'space_native.gdextension'), $extensionText)
    Write-Output $nativeDll
} finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
}
