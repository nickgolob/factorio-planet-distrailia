# Distrailia test runner (Windows / local).
#
# Runs the two suites that don't need Factorio itself:
#   1. luacheck   -- static analysis (tools/bin/luacheck.exe, or luacheck on PATH)
#   2. unit tests -- pure logic via Lua + tools/run_specs.lua (busted-compatible specs)
#
# CI (.github/workflows/test.yml) runs the same .luacheckrc and spec/ files with the canonical
# luacheck + busted on Linux. In-game integration tests (FactorioTest) need a Factorio binary and
# are not run here.
#
# First-time setup (binaries are gitignored under tools/bin/):
#   Lua:      winget install DEVCOM.Lua
#   luacheck: download luacheck.exe into tools/bin/ from
#             https://github.com/lunarmodules/luacheck/releases

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
$targets = @("control.lua", "data.lua", "prototypes", "lib", "spec", "tools")

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

if ($failed) {
  Write-Host "`nTESTS FAILED" -ForegroundColor Red
  exit 1
}
Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
