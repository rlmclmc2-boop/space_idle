# Same exclusive Windows file-handle lock as Python and SpaceSaveLock.
function Get-ConfigurationSnapshot([string]$Root) {
    $base = [IO.Path]::GetFullPath($Root)
    $lease = [IO.File]::Open((Join-Path $base '.configuration-lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        if ([IO.File]::Exists((Join-Path $base '.configuration-transaction.json'))) { throw 'Configuration recovery required; run the publisher recovery first' }
        $raw = [IO.File]::ReadAllBytes((Join-Path $base 'configuration_manifest.json'))
        $manifest = [Text.Encoding]::UTF8.GetString($raw) | ConvertFrom-Json
        if ($manifest.version -ne 1 -or !$manifest.files -or @($manifest.files.PSObject.Properties).Count -eq 0) { throw 'Invalid configuration manifest' }
        $captured = @{}; $members = @{}
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $identity = [BitConverter]::ToString($sha.ComputeHash($raw)).Replace('-','').ToLowerInvariant()
            foreach ($member in $manifest.files.PSObject.Properties) {
                $name = $member.Name
                if ($name -notmatch '^(data|config_excel)/' -or $name.Contains('..') -or $name.Contains('\') -or $name.Contains(':')) { throw "Invalid configuration member: $name" }
                $path = Join-Path $base $name
                $probe = $path
                while ($probe -ne $base) {
                    if (([IO.File]::GetAttributes($probe) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Configuration member is a link: $name" }
                    $probe = [IO.Path]::GetDirectoryName($probe)
                }
                $bytes = [IO.File]::ReadAllBytes($path)
                $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
                if ($bytes.Length -ne $member.Value.size -or $hash -cne $member.Value.sha256) { throw "Configuration generation mismatch: $name" }
                if (@($name.Split('/') | Where-Object { $_.StartsWith('.') }).Count -eq 0) {
                    $captured[$name] = $bytes
                    $members[$name] = @{ sha256=$hash; size=$bytes.Length }
                }
            }
        } finally { $sha.Dispose() }
        # A package carries the complete runtime projection and its source identity.
        $package = @{ version=1; source_generation=$identity; files=$members } | ConvertTo-Json -Depth 8 -Compress
        $captured['configuration_manifest.json'] = [Text.Encoding]::UTF8.GetBytes($package)
        return $captured
    } finally { $lease.Dispose() }
}
