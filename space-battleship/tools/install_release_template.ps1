# Fetch the official, version-pinned standard Windows release template only.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$engine = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../engine'))
$download = Join-Path $engine 'downloads'
$target = Join-Path $engine 'templates/4.7.2.stable/windows_release_x86_64.exe'
$archive = Join-Path $download 'templates.tpz'
$expected = 'ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079'
$url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
try {
    New-Item -ItemType Directory -Force -Path $download, (Split-Path $target) | Out-Null
    if (!(Test-Path -LiteralPath $archive)) {
        Write-Host "Downloading official export templates (about 1.3 GB): $url"
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile ($archive + '.partial')
        Move-Item -LiteralPath ($archive + '.partial') -Destination $archive
    }
    Write-Host "Verifying SHA512: $archive"
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash.ToLowerInvariant() -ne $expected) {
        throw "Checksum mismatch: $archive. Remove this damaged download and run this installer again."
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $entry = $zip.GetEntry('templates/windows_release_x86_64.exe')
        if (!$entry) { throw "Windows release template missing inside $archive" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target + '.partial', $true)
    } finally { $zip.Dispose() }
    Move-Item -LiteralPath ($target + '.partial') -Destination $target -Force
    Write-Host "Installed: $target"
} catch {
    Write-Error "Template setup failed: $($_.Exception.Message)`nDownload: $archive`nTarget: $target" -ErrorAction Continue
    exit 1
}
exit 0
