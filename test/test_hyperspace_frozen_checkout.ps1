param([string]$Repository = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$scratch = Join-Path $env:TEMP ('space-frozen-checkout-' + [guid]::NewGuid())
$relative = 'space-battleship/data/space_enemy_reward_sources.json'
$expected = '4c92f2168c9c9b36da933934a10d4cfe4226870825b43dd228c3132ba4b8780a'
function Invoke-TestGit([string[]]$Arguments) {
    & git.exe -C $scratch @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $Arguments" }
}
try {
    New-Item -ItemType Directory -Path (Join-Path $scratch 'space-battleship/data') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Repository $relative) -Destination (Join-Path $scratch $relative)
    Invoke-TestGit -Arguments @('init','--quiet')
    Invoke-TestGit -Arguments @('config','core.autocrlf','false')
    Invoke-TestGit -Arguments @('add','--',$relative)
    Invoke-TestGit -Arguments @('config','core.autocrlf','true')
    Remove-Item -LiteralPath (Join-Path $scratch $relative)
    Invoke-TestGit -Arguments @('checkout-index','--force','--',$relative)
    $before = (Get-FileHash -LiteralPath (Join-Path $scratch $relative) -Algorithm SHA256).Hash.ToLower()
    if ($before -eq $expected) { throw 'Control checkout failed to reproduce CRLF mismatch' }
    Copy-Item -LiteralPath (Join-Path $Repository '.gitattributes') -Destination (Join-Path $scratch '.gitattributes')
    Invoke-TestGit -Arguments @('add','--','.gitattributes')
    Remove-Item -LiteralPath (Join-Path $scratch $relative)
    Invoke-TestGit -Arguments @('checkout-index','--force','--',$relative)
    $after = (Get-FileHash -LiteralPath (Join-Path $scratch $relative) -Algorithm SHA256).Hash.ToLower()
    if ($after -ne $expected) { throw "Protected checkout SHA256 mismatch: $after" }
    Write-Output "PASS: autocrlf=true; unprotected=$before; protected=$after"
} finally {
    $resolved = [IO.Path]::GetFullPath($scratch)
    $tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
