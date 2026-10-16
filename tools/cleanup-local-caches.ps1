# Windows PowerShell 5.1+. Preview by default; -Recycle enables selection.
# No AI/network calls. Main project, saves, tools and entire worktrees are excluded.
[CmdletBinding()]
param([switch]$Recycle)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root='D:\CodexBuild\space_idle'
function Is-Link($Item) { return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) }
function Inspect-Cache([string]$Path,[string]$Kind) {
    if(Is-Link (Get-Item -LiteralPath $Path -Force)){throw "Link: $Path"}
    $q=New-Object 'System.Collections.Generic.Queue[string]'
    $q.Enqueue($Path); [long]$bytes=0; [long]$count=0
    while($q.Count -gt 0){
        foreach($e in Get-ChildItem -LiteralPath $q.Dequeue() -Force){
            if(Is-Link $e){throw "Link inside cache: $($e.FullName)"}
            if($e.PSIsContainer){$q.Enqueue($e.FullName)}
            else {
                if($Kind -eq 'Python' -and $e.Extension -notin @('.pyc','.pyo')){throw "Non-cache file: $($e.FullName)"}
                $bytes+=$e.Length; $count++
            }
        }
    }
    $parent=Split-Path -Parent $Path; $leaf=Split-Path -Leaf $Path
    # Fail closed when Git cannot verify that the cache contains no tracked files.
    $old=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    $tracked=@(& git -c "safe.directory=$parent" -C $parent ls-files -- "$leaf/" 2>$null)
    $code=$LASTEXITCODE; $ErrorActionPreference=$old
    if($code -eq 0 -and $tracked.Count -gt 0){throw "Git-tracked cache files: $Path"}
    if($code -ne 0){throw "Git could not verify this cache; skipped: $Path"}
    return [pscustomobject]@{Path=$Path;Kind=$Kind;Bytes=$bytes;Files=$count}
}
function Check-Idle {
    $busy=@(Get-Process | Where-Object {$_.ProcessName -match '^(Godot|python|pythonw)'})
    if($busy.Count){
        $busy | Select-Object ProcessName,Id | Format-Table | Out-Host
        throw 'Close Godot/Python yourself before cleanup. No process was stopped.'
    }
}
if($env:OS -ne 'Windows_NT'){throw 'Windows only.'}
if(-not(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git is required.'}
if(-not(Test-Path -LiteralPath $Root -PathType Container)){throw "Missing: $Root"}
if(Is-Link (Get-Item -LiteralPath $Root -Force)){throw 'QA root is a link.'}
$candidates=New-Object System.Collections.Generic.List[object]
$skipped=New-Object System.Collections.Generic.List[string]
$q=New-Object 'System.Collections.Generic.Queue[string]'
$q.Enqueue($Root)
while($q.Count -gt 0){
    $dir=$q.Dequeue()
    try {
        foreach($e in Get-ChildItem -LiteralPath $dir -Directory -Force){
            if(Is-Link $e){$skipped.Add("Link: $($e.FullName)");continue}
            if($e.Name -in @('.git','node_modules','venv','.venv')){continue}
            $kind=''
            if($e.Name -eq '.godot' -and (Test-Path -LiteralPath (Join-Path $dir 'project.godot') -PathType Leaf)){$kind='Godot'}
            if($e.Name -eq '__pycache__'){$kind='Python'}
            if($kind){
                try {$candidates.Add((Inspect-Cache $e.FullName $kind))}
                catch {$skipped.Add($_.Exception.Message)}
            } else {$q.Enqueue($e.FullName)}
        }
    } catch {$skipped.Add("Unreadable: $dir")}
}
Write-Host 'Only generated caches under D:\CodexBuild\space_idle are candidates.'
Write-Host 'Main project, saves, source, Excel, assets, DLLs, tools, logs and worktrees are retained.'
for($i=0;$i -lt $candidates.Count;$i++){
    $c=$candidates[$i]
    Write-Host ("[{0}] {1:N2} MiB | {2} files | {3}" -f ($i+1),($c.Bytes/1MB),$c.Files,$c.Path)
}
if($skipped.Count){Write-Host 'Skipped:';$skipped | ForEach-Object {Write-Host $_}}
if(-not $candidates.Count){Write-Host 'No verified generated caches found.';exit 0}
if(-not $Recycle){
    Write-Host 'Preview only. No files changed. Run again with -Recycle to select caches.'
    exit 0
}
Check-Idle
$choice=Read-Host 'Enter cache numbers separated by commas, or Enter to cancel'
if([string]::IsNullOrWhiteSpace($choice)){exit 0}
if($choice -notmatch '^\s*\d+(\s*,\s*\d+)*\s*$'){throw 'Invalid selection.'}
$indices=@($choice.Split(',') | ForEach-Object {[int]$_.Trim()-1} | Select-Object -Unique)
foreach($i in $indices){if($i -lt 0 -or $i -ge $candidates.Count){throw 'Index out of range.'}}
$selected=@($indices | ForEach-Object {$candidates[$_]})
$selected | Select-Object Path,Files,@{n='MiB';e={[math]::Round($_.Bytes/1MB,2)}} | Format-Table -AutoSize | Out-Host
Write-Host 'Recycle Bin only. CANCEL any Windows dialog offering permanent deletion.'
Write-Host 'The Recycle Bin will NOT be emptied. Moving files there may not free disk space.'
if((Read-Host 'Type RECYCLE to continue') -cne 'RECYCLE'){exit 0}
Add-Type -AssemblyName Microsoft.VisualBasic
foreach($c in $selected){
    Check-Idle
    $now=Inspect-Cache $c.Path $c.Kind
    if($now.Bytes -ne $c.Bytes -or $now.Files -ne $c.Files){throw "Cache changed: $($c.Path)"}
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
        $c.Path,
        [Microsoft.VisualBasic.FileIO.UIOption]::AllDialogs,
        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
        [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
    if(Test-Path -LiteralPath $c.Path){throw "Still present: $($c.Path)"}
    Write-Host "Moved to Recycle Bin: $($c.Path)"
}
Write-Host 'Finished. No permanent-delete fallback was executed by this script.'
