# Visual-test runner (AUTONOMOUS capture) -- infrastructure for the visual tests.
#
# Drives a SEPARATE, ISOLATED Factorio instance (its own --mod-directory = .factorio-test-data) to run
# the visual suite and write PNGs to script-output. The isolated data dir means it never touches your
# live save/mods/config and can run while your game is open.
#
# Two modes:
#   (default)  Off-screen goldens (sprite + network). The window is parked OFF-SCREEN the whole time.
#   -Cursor    The REAL build-cursor preview. The preview only renders for a genuine HARDWARE mouse
#              over an on-screen, focused client (Factorio ignores synthetic/injected mouse input --
#              verified). So this opens the instance ON-SCREEN and hands it focus, then YOU move your
#              real mouse over it and hold where you'd place it for a few seconds while it shoots
#              several frames; afterwards it restores your previous window. No save/mod impact.
#
# Why a window appears: take_screenshot needs a real GPU/display (visible desktop only). config.ini
# forces windowed full-screen=false at 1280x720; the Steam graphics client needs steam_appid.txt.
#
# Usage:  powershell -ExecutionPolicy Bypass -File visual_tests\run.ps1 [-TimeoutSec 240] [-Cursor] [-HoldSec 12]

param([int]$TimeoutSec = 240, [switch]$Cursor, [int]$HoldSec = 12)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$appid = Join-Path $root "steam_appid.txt"
if (-not (Test-Path $appid)) { Set-Content -Path $appid -Value "427520" -NoNewline }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, IntPtr v, uint flags);
  // Force a window to the foreground past Windows' foreground lock.
  public static void ForceForeground(IntPtr h) {
    SystemParametersInfo(0x2001, 0, IntPtr.Zero, 0); // SPI_SETFOREGROUNDLOCKTIMEOUT = 0
    IntPtr fore = GetForegroundWindow();
    uint foreThread = GetWindowThreadProcessId(fore, IntPtr.Zero);
    uint me = GetCurrentThreadId();
    if (foreThread != me) { AttachThreadInput(foreThread, me, true); }
    ShowWindow(h, 9); BringWindowToTop(h); SetForegroundWindow(h); // SW_RESTORE
    if (foreThread != me) { AttachThreadInput(foreThread, me, false); }
  }
}
"@
$PARK = [uint32](0x0001 -bor 0x0004 -bor 0x0010) # SWP_NOSIZE|NOZORDER|NOACTIVATE (shove off-screen)
$SHOW = [uint32]0x0040                            # SWP_SHOWWINDOW (move+size+show+raise on-screen)

& (Join-Path $root "tools\patch-factorio-test-cli.ps1") | Out-Null
$ftMod = @(Get-ChildItem (Join-Path $root ".factorio-test-data\mods") -Filter "factorio-test_*.zip" -ErrorAction SilentlyContinue)
if (-not $ftMod -or $ftMod.Count -eq 0) { Write-Error "factorio-test mod not staged - see TESTING.md."; exit 1 }

$out = Join-Path $root ".factorio-test-data\script-output\distrailia"
New-Item -ItemType Directory -Force $out | Out-Null
$cliOut = Join-Path $root ".factorio-test-data\shot-cli.log"

function Get-IsolatedFactorio {
  Get-CimInstance Win32_Process -Filter "Name = 'factorio.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*.factorio-test-data*" }
}
function Get-IsolatedHwnd {
  $fp = Get-IsolatedFactorio | Select-Object -First 1
  if (-not $fp) { return [IntPtr]::Zero }
  $proc = Get-Process -Id $fp.ProcessId -ErrorAction SilentlyContinue
  if ($proc) { $proc.Refresh(); return $proc.MainWindowHandle }
  return [IntPtr]::Zero
}
function Stop-Isolated($cli) {
  foreach ($p in @(Get-IsolatedFactorio)) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
  if ($cli -and -not $cli.HasExited) { cmd /c "taskkill /T /F /PID $($cli.Id) >nul 2>&1" }
}

if (-not $Cursor) {
  # -------- default: off-screen goldens --------
  Get-ChildItem "$out\01-*.png","$out\02-*.png" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  $userHwnd = [W]::GetForegroundWindow()
  Write-Host "Launching isolated Factorio (windowed graphics, parked off-screen)..." -ForegroundColor Cyan
  $cli = Start-Process -PassThru -WindowStyle Hidden -WorkingDirectory $root -FilePath "cmd.exe" `
    -ArgumentList "/c", "npx --no-install factorio-test run -g -- screenshot" `
    -RedirectStandardOutput $cliOut -RedirectStandardError "$cliOut.err"
  $fhwnd = [IntPtr]::Zero
  $deadline = (Get-Date).AddSeconds($TimeoutSec); $ok = $false
  while ((Get-Date) -lt $deadline) {
    if ($fhwnd -eq [IntPtr]::Zero) { $fhwnd = Get-IsolatedHwnd }
    if ($fhwnd -ne [IntPtr]::Zero) {
      [W]::ShowWindow($fhwnd, 4) | Out-Null
      [W]::SetWindowPos($fhwnd, [IntPtr]::Zero, -4000, -4000, 0, 0, $PARK) | Out-Null
      if ($userHwnd -ne [IntPtr]::Zero -and [W]::GetForegroundWindow() -eq $fhwnd) { [W]::SetForegroundWindow($userHwnd) | Out-Null }
    }
    if (@(Get-ChildItem "$out\01-*.png","$out\02-*.png" -ErrorAction SilentlyContinue).Count -ge 2) { Start-Sleep -Milliseconds 1500; $ok = $true; break }
    Start-Sleep -Milliseconds 60
  }
  Stop-Isolated $cli
  $pngs = @(Get-ChildItem "$out\01-*.png","$out\02-*.png" -ErrorAction SilentlyContinue | Sort-Object Name)
  if (-not $ok -or $pngs.Count -eq 0) { Write-Warning "No screenshots in ${TimeoutSec}s. CLI tail:"; if (Test-Path $cliOut) { Get-Content $cliOut -Tail 15 }; exit 1 }
  Write-Host "`nScreenshots written:" -ForegroundColor Green
  foreach ($p in $pngs) { Write-Host ("  {0}  ({1:n0} bytes)" -f $p.FullName, $p.Length) }
  exit 0
}

# -------- -Cursor: real build-cursor preview (YOU move the mouse) --------
Get-ChildItem "$out\cursor-*.png" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$ready = Join-Path $out "cursor-ready.txt"
Remove-Item $ready -Force -ErrorAction SilentlyContinue
$userHwnd = [W]::GetForegroundWindow()

Write-Host "Launching isolated Factorio for the build-cursor preview..." -ForegroundColor Cyan
$cli = Start-Process -PassThru -WindowStyle Hidden -WorkingDirectory $root -FilePath "cmd.exe" `
  -ArgumentList "/c", "npx --no-install factorio-test run -g -- cursor" `
  -RedirectStandardOutput $cliOut -RedirectStandardError "$cliOut.err"

# 1) Keep the window off-screen until the game signals it's loaded + about to shoot.
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$fhwnd = [IntPtr]::Zero
while ((Get-Date) -lt $deadline -and -not (Test-Path $ready)) {
  if ($fhwnd -eq [IntPtr]::Zero) { $fhwnd = Get-IsolatedHwnd }
  if ($fhwnd -ne [IntPtr]::Zero) {
    [W]::ShowWindow($fhwnd, 4) | Out-Null
    [W]::SetWindowPos($fhwnd, [IntPtr]::Zero, -4000, -4000, 0, 0, $PARK) | Out-Null
    if ($userHwnd -ne [IntPtr]::Zero -and [W]::GetForegroundWindow() -eq $fhwnd) { [W]::SetForegroundWindow($userHwnd) | Out-Null }
  }
  Start-Sleep -Milliseconds 80
}

# 2) Ready: bring it ON-SCREEN + focused and HOLD. You move your real mouse over it and aim.
if (Test-Path $ready) {
  if ($fhwnd -eq [IntPtr]::Zero) { $fhwnd = Get-IsolatedHwnd }
  Write-Host "`n>>> A Factorio window is now on-screen. MOVE YOUR MOUSE over it and HOLD where you'd place" -ForegroundColor Yellow
  Write-Host ">>> the superroboport (near the structure shown). Capturing ~$HoldSec s..." -ForegroundColor Yellow
  [W]::SetWindowPos($fhwnd, [IntPtr]::Zero, 0, 0, 1280, 720, $SHOW) | Out-Null
  [W]::ForceForeground($fhwnd)
  $holdUntil = (Get-Date).AddSeconds($HoldSec)
  while ((Get-Date) -lt $holdUntil) {
    [W]::SetWindowPos($fhwnd, [IntPtr]::Zero, 0, 0, 1280, 720, $SHOW) | Out-Null
    if ([W]::GetForegroundWindow() -ne $fhwnd) { [W]::ForceForeground($fhwnd) } # keep it focused (don't touch the mouse)
    if (Test-Path (Join-Path $out "cursor-10.png")) { Start-Sleep -Milliseconds 800; break }
    Start-Sleep -Milliseconds 150
  }
}

# 3) Restore the user's window (do NOT move the cursor -- you're holding it), then tear down.
if ($fhwnd -ne [IntPtr]::Zero) { [W]::SetWindowPos($fhwnd, [IntPtr]::Zero, -4000, -4000, 0, 0, $PARK) | Out-Null }
if ($userHwnd -ne [IntPtr]::Zero) { [W]::SetForegroundWindow($userHwnd) | Out-Null }
Stop-Isolated $cli

$frames = @(Get-ChildItem "$out\cursor-*.png" -ErrorAction SilentlyContinue | Sort-Object Name)
if ($frames.Count -eq 0) {
  Write-Warning "No cursor frames produced (ready=$(Test-Path $ready)). CLI tail:"; if (Test-Path $cliOut) { Get-Content $cliOut -Tail 15 }; exit 1
}
Write-Host "`nCursor frames written ($($frames.Count)):" -ForegroundColor Green
foreach ($p in $frames) { Write-Host ("  {0}  ({1:n0} bytes)" -f $p.FullName, $p.Length) }
