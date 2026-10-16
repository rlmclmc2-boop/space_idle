# Read-only disk inventory for the main Space Idle repository.
# No deletion, network, AI calls, Git checkout, reset, clean or stash.
[CmdletBinding()]
param([string]$Root=('D:\'+[char]0x653e+[char]0x7f6e))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root).TrimEnd('\')
Write-Host "Read-only inventory: $Root"
Write-Host 'No files in the project will be modified. Press Ctrl+C to cancel.'
if(-not(Test-Path -LiteralPath $Root -PathType Container)){throw 'Root directory not found.'}
if(-not(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git is required.'}
function Git-Paths([string[]]$Arguments) {
    $result=@(& git -c "safe.directory=$Root" -c core.quotepath=false -C $Root @Arguments)
    if($LASTEXITCODE -ne 0){throw 'Git inventory failed; stop without guessing file status.'}
    $set=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($p in (($result -join [Environment]::NewLine).Split([char]0))){
        if($p.Length){[void]$set.Add($p.Replace('/','\'))}
    }
    return ,$set
}
$tracked=Git-Paths @('ls-files','-z')
$ignored=Git-Paths @('ls-files','--others','--ignored','--exclude-standard','-z')
Write-Host 'Current Git changes (these are NOT disposable):'
& git -c "safe.directory=$Root" -c core.quotepath=false -C $Root status --short
if($LASTEXITCODE -ne 0){throw 'Git status failed.'}
$rows=New-Object System.Collections.Generic.List[object]
$skipped=New-Object System.Collections.Generic.List[string]
$q=New-Object 'System.Collections.Generic.Queue[string]'
$q.Enqueue($Root)
$timer=[Diagnostics.Stopwatch]::StartNew();$last=-3
while($q.Count -gt 0){
    $dir=$q.Dequeue()
    if($timer.Elapsed.TotalSeconds-$last -ge 2){
        $last=$timer.Elapsed.TotalSeconds
        Write-Host ("[{0:N0}s] {1} files; {2}" -f $last,$rows.Count,$dir)
    }
    try {
        foreach($e in Get-ChildItem -LiteralPath $dir -Force){
            if(($e.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){
                $skipped.Add("Link skipped: $($e.FullName)");continue
            }
            if($e.PSIsContainer){$q.Enqueue($e.FullName);continue}
            $relative=$e.FullName.Substring($Root.Length+1)
            $parts=$relative.Split('\')
            $group=if($parts.Length -gt 2){$parts[0]+'\'+$parts[1]}else{$parts[0]}
            $category='Untracked: review, do not auto-delete'
            if($relative -eq '.git' -or $relative.StartsWith('.git\',[StringComparison]::OrdinalIgnoreCase)){
                $category='Git metadata: keep'
            } elseif($tracked.Contains($relative)){
                $category='Git tracked: keep'
            } elseif($ignored.Contains($relative)){
                $category='Git ignored: review, not necessarily disposable'
            }
            $cache=($parts -contains '.godot' -or $parts -contains '__pycache__')
            $rows.Add([pscustomobject]@{
                Path=$relative;Bytes=$e.Length;MiB=[math]::Round($e.Length/1MB,3)
                Group=$group;Category=$category;CacheNameHint=$cache
            })
        }
    } catch {$skipped.Add("Unreadable directory: $dir")}
}
Write-Host 'Largest directory groups:'
$rows | Group-Object Group | ForEach-Object {
    [pscustomobject]@{Group=$_.Name;MiB=[math]::Round(($_.Group | Measure-Object Bytes -Sum).Sum/1MB,2);Files=$_.Count}
} | Sort-Object MiB -Descending | Select-Object -First 25 | Format-Table -AutoSize | Out-Host
Write-Host 'Largest individual files:'
$rows | Sort-Object Bytes -Descending | Select-Object -First 20 Path,MiB,Category | Format-Table -AutoSize | Out-Host
Write-Host 'Category totals:'
$rows | Group-Object Category | ForEach-Object {
    [pscustomobject]@{Category=$_.Name;MiB=[math]::Round(($_.Group | Measure-Object Bytes -Sum).Sum/1MB,2);Files=$_.Count}
} | Format-Table -AutoSize | Out-Host
if($skipped.Count){Write-Host 'Incomplete coverage:';$skipped | ForEach-Object {Write-Host $_}}
Write-Host 'Nothing deleted. Ignored/untracked files and cache names are not deletion approval.'
$out=Read-Host 'Optional CSV report path outside the project, or Enter to finish'
if(-not [string]::IsNullOrWhiteSpace($out)){
    $full=[IO.Path]::GetFullPath($out)
    if($full.Equals($Root,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw 'Choose a report location outside the project.'
    }
    if(Test-Path -LiteralPath $full){throw 'Report already exists; will not overwrite.'}
    $rows | Export-Csv -LiteralPath $full -NoTypeInformation -Encoding UTF8
    Write-Host "Saved inventory: $full"
}
