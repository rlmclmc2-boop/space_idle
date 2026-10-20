$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Sha256([string]$path) {
    $hash = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($path)
    try {
        return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $hash.Dispose()
    }
}

try {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'The player entry supports Windows x64 only.'
    }
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $runtime = Join-Path $root 'space-battleship/.runtime'
    $downloads = Join-Path $runtime 'downloads'
    $pythonDir = Join-Path $runtime 'player-python-3.12.10'
    $python = Join-Path $pythonDir 'python.exe'
    $archive = Join-Path $downloads 'python-3.12.10-embed-amd64.zip'
    $url = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip'
    $archiveHash = '4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3'
    $fileHashes = @{
        'python.exe' = '4d6f5f81a4bca11191c4c7c6b43632694d0a4ce74e068619d8fdc161d469859a'
        'python312.dll' = '9a0e3435aaa680d868150f87ab3e388ad2eebc22f87e036155c7b4eda8cd2120'
        'python312.zip' = 'fb131c0ef7e35cc5250a74c8cd18744bf4115fb8163710711f3758d7df3d1f88'
    }
    New-Item -ItemType Directory -Force -Path $downloads | Out-Null
    if (-not (Test-Path -LiteralPath $pythonDir)) {
        if (-not (Test-Path -LiteralPath $archive)) {
            $partial = $archive + '.' + $PID + '.partial'
            try {
                Write-Host 'Downloading the pinned Python player runtime from python.org...'
                Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $partial
                if ((Get-Sha256 $partial) -ne $archiveHash) {
                    throw 'Python download failed SHA256 verification.'
                }
                Move-Item -LiteralPath $partial -Destination $archive
            } finally {
                if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial }
            }
        }
        if ((Get-Sha256 $archive) -ne $archiveHash) {
            throw 'Cached Python runtime failed SHA256 verification.'
        }
        $staging = $pythonDir + '.' + $PID + '.partial'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $staging)
        foreach ($item in $fileHashes.GetEnumerator()) {
            $path = Join-Path $staging $item.Key
            if ((Get-Sha256 $path) -ne $item.Value) {
                throw ('Python runtime file failed SHA256 verification: ' + $item.Key)
            }
        }
        Move-Item -LiteralPath $staging -Destination $pythonDir
    }
    foreach ($item in $fileHashes.GetEnumerator()) {
        $path = Join-Path $pythonDir $item.Key
        if ((Get-Sha256 $path) -ne $item.Value) {
            throw ('Installed player Python runtime is missing or changed: ' + $path)
        }
    }
    & $python (Join-Path $root 'tools/play_main.py')
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine('Player startup failed: ' + $_.Exception.Message)
    exit 1
}
