param(
    [Parameter(Mandatory=$true)][int]$GamePid,
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [string]$CaptureDir = 'evidence\review-a\input-probe'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$capture = Join-Path $root $CaptureDir
New-Item -ItemType Directory -Force -Path $capture | Out-Null

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ReviewWindow {
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr arg);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr arg);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int len);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
}
'@

$before = Get-ChildItem -LiteralPath $capture -Filter 'frame-*.jpg' | Sort-Object Name | Select-Object -Last 1
if (-not $before) { Write-Output 'failure=no_current_capture'; exit 1 }
Write-Output "before=$($before.FullName)"

$game = Get-Process -Id $GamePid -ErrorAction Stop
if ($game.ProcessName -notlike '*godot*') { throw "PID $GamePid is not Godot" }
Write-Output "godot_pid=$GamePid"
$windows = [System.Collections.Generic.List[object]]::new()
$cb = [ReviewWindow+EnumWindowsProc] {
    param([IntPtr]$hwnd, [IntPtr]$arg)
    [uint32]$pidValue = 0
    [void][ReviewWindow]::GetWindowThreadProcessId($hwnd, [ref]$pidValue)
    if ([int]$pidValue -eq $GamePid) {
        $title = [Text.StringBuilder]::new(256)
        [void][ReviewWindow]::GetWindowText($hwnd, $title, $title.Capacity)
        $windows.Add([pscustomobject]@{ Hwnd=$hwnd; PID=$pidValue; Title=$title.ToString(); Valid=[ReviewWindow]::IsWindow($hwnd) })
    }
    return $true
}
$enumOk = [ReviewWindow]::EnumWindows($cb, [IntPtr]::Zero)
Write-Output "enum_ok=$enumOk windows=$($windows.Count)"
foreach ($w in $windows) { Write-Output "window_pid=$($w.PID) hwnd=$($w.Hwnd) valid=$($w.Valid) title=$($w.Title)" }
$target = $windows | Where-Object { $_.Valid -and $_.Title -and $_.Title -notlike '*wglDummy*' -and $_.Title -notlike '*IME*' } | Select-Object -First 1
if (-not $target) { Write-Output 'failure=no_fresh_valid_godot_window'; exit 2 }

# Coordinates must come from the captured game UI; this sends only ordinary mouse messages.
$lparam = [IntPtr](($Y -shl 16) -bor $X)
$validImmediatelyBefore = [ReviewWindow]::IsWindow($target.Hwnd)
$down = [ReviewWindow]::PostMessage($target.Hwnd, 0x0201, [IntPtr]1, $lparam)
$downError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
$up = [ReviewWindow]::PostMessage($target.Hwnd, 0x0202, [IntPtr]::Zero, $lparam)
$upError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
Write-Output "click_valid=$validImmediatelyBefore down=$down down_error=$downError up=$up up_error=$upError x=$X y=$Y"
Start-Sleep -Seconds 2
$after = Get-ChildItem -LiteralPath $capture -Filter 'frame-*.jpg' | Sort-Object Name | Select-Object -Last 1
Write-Output "after=$($after.FullName)"
