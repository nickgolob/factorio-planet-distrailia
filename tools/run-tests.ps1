# Distrailia test runner (Windows / local).
#
# Default: the two suites that don't need Factorio:
#   1. luacheck   -- static analysis (tools/bin/luacheck.exe, or luacheck on PATH)
#   2. unit tests -- pure logic via Lua + tools/run_specs.lua (busted-compatible specs)
#
# With -Integration: also runs the in-game FactorioTest suite (tests/) headless via
# factorio-test-cli (requires the integration toolchain set up per TESTING.md).
#
# First-time setup (binaries are gitignored under tools/bin/):
#   Lua:      winget install DEVCOM.Lua
#   luacheck: download luacheck.exe into tools/bin/ from
#             https://github.com/lunarmodules/luacheck/releases

param([switch]$Integration)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Find-Exe([string[]]$candidates, [string]$onPath) {
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  $g = Get-Command $onPath -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  return $null
}

$lua = Find-Exe @(
  "C:\MY PROGRAMS\Lua\bin\lua.exe",
  (Join-Path $root "tools\bin\lua\lua.exe"),
  "C:\Program Files\Lua\bin\lua.exe"
) "lua"

$luacheck = Find-Exe @((Join-Path $root "tools\bin\luacheck.exe")) "luacheck"

$failed = $false
$targets = @("control.lua", "data.lua", "prototypes", "lib", "spec", "tests", "tools")

Write-Host "== luacheck ==" -ForegroundColor Cyan
if ($luacheck) {
  & $luacheck @targets
  if ($LASTEXITCODE -ne 0) { $failed = $true }
} else {
  Write-Warning "luacheck not found (tools/bin/luacheck.exe or PATH). Skipping static analysis."
}

Write-Host "`n== unit tests ==" -ForegroundColor Cyan
if ($lua) {
  $specs = @(Get-ChildItem -Path (Join-Path $root "spec") -Filter "*_spec.lua" -ErrorAction SilentlyContinue |
    ForEach-Object { "spec/$($_.Name)" })
  if (-not $specs -or $specs.Count -eq 0) {
    Write-Warning "no spec files found under spec/"
  } else {
    & $lua "tools/run_specs.lua" @specs
    if ($LASTEXITCODE -ne 0) { $failed = $true }
  }
} else {
  Write-Error "lua.exe not found. Install with: winget install DEVCOM.Lua"
  $failed = $true
}

if ($Integration) {
  Write-Host "`n== integration tests (FactorioTest, headless) ==" -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot "patch-factorio-test-cli.ps1")
  $ftMod = @(Get-ChildItem (Join-Path $root ".factorio-test-data\mods") -Filter "factorio-test_*.zip" -ErrorAction SilentlyContinue)
  if (-not $ftMod -or $ftMod.Count -eq 0) {
    Write-Warning "factorio-test mod not staged in .factorio-test-data\mods\ - see TESTING.md. Skipping integration."
    $failed = $true
  } else {
    & npx --no-install factorio-test run --output-timeout 120
    if ($LASTEXITCODE -ne 0) { $failed = $true }
  }
}

if ($failed) {
  Write-Host "`nTESTS FAILED" -ForegroundColor Red
  exit 1
}
Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
