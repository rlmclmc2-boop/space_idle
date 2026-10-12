param(
    [string]$BuildRoot = 'D:\CodexBuild\space_idle',
    [string]$ToolsRoot = 'D:\CodexTools',
    [int]$Jobs = 8
)
$ErrorActionPreference = 'Stop'
$buildPath = [IO.Path]::GetFullPath($BuildRoot)
$toolsPath = [IO.Path]::GetFullPath($ToolsRoot)
if ([IO.Path]::GetPathRoot($buildPath) -ne 'D:\' -or [IO.Path]::GetPathRoot($toolsPath) -ne 'D:\') {
    throw 'This authorized build keeps tools, caches, generated files and outputs on D:.'
}
$binding = Join-Path $buildPath 'godot-cpp'
$compiler = Join-Path $toolsPath 'llvm-mingw\llvm-mingw-20261006-ucrt-x86_64'
$python = Join-Path $toolsPath 'venv\godot-native\Scripts\python.exe'
$api = Join-Path $buildPath 'api\extension_api.json'
$native = Join-Path $buildPath 'native'
$expectedBinding = '507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'
$bindingHead = & git -c safe.directory='*' -C $binding rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $bindingHead -ne $expectedBinding) { throw 'Requires official godot-cpp 10.0.0-stable at the pinned commit.' }
if ((Get-FileHash -LiteralPath $api -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986') {
    throw 'API must be the verified single-precision local Godot 4.7.2 export.'
}
# Changes to these environment variables exist only inside this build process.
$saved = @{}
foreach ($key in 'TEMP','TMP','PATH','PYTHONPYCACHEPREFIX','PIP_CACHE_DIR') { $saved[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
try {
    $env:TEMP = Join-Path $toolsPath 'tmp'; $env:TMP = $env:TEMP
    $env:PYTHONPYCACHEPREFIX = Join-Path $toolsPath 'cache\pycache'
    $env:PIP_CACHE_DIR = Join-Path $toolsPath 'cache\pip'
    $env:PATH = (Join-Path $compiler 'bin') + ';' + $env:PATH
    New-Item -ItemType Directory -Force -Path (Join-Path $native 'src') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SConstruct') -Destination (Join-Path $native 'SConstruct')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\space_native.cpp') -Destination (Join-Path $native 'src\space_native.cpp')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'src\combat_execution_kernel.h') -Destination (Join-Path $native 'src\combat_execution_kernel.h')
    Push-Location $native
    try {
        & $python -m SCons "bindings=$($binding.Replace('\','/'))" platform=windows arch=x86_64 use_mingw=yes use_llvm=yes "mingw_prefix=$($compiler.Replace('\','/'))" use_static_cpp=yes "custom_api_file=$($api.Replace('\','/'))" target=template_release lto=none -j $Jobs
        if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
    } finally { Pop-Location }
    Write-Output (Join-Path $native 'bin\space_native.dll')
} finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
}
