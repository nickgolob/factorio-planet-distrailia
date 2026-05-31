# Re-applies a small Windows fix to the (gitignored) factorio-test-cli in node_modules.
#
# Upstream the CLI does `spawn("npx", ["fmtk", ...])` with no shell, which on Windows fails with
# `spawn npx ENOENT` (npx is npx.cmd) and also mangles paths containing spaces. We rewrite its
# runScript() to invoke fmtk's CLI JS directly with the current node executable.
#
# Idempotent. Run after `npm install`; tools/run-tests.ps1 -Integration calls this automatically.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root "node_modules\factorio-test-cli\process-utils.js"

if (-not (Test-Path $file)) {
  Write-Warning "factorio-test-cli not installed (run: npm install -D factorio-test-cli). Skipping patch."
  return
}

$content = Get-Content $file -Raw
if ($content -match "Windows fix:") {
  Write-Host "factorio-test-cli already patched."
  return
}

$old = @'
export function runScript(...command) {
    return runProcess(verbose, "npx", ...command);
}
'@

$new = @'
import { fileURLToPath as __ft_fileURLToPath } from "url";
export function runScript(...command) {
    // Windows fix: upstream does spawn("npx", ["fmtk", ...]) which fails with ENOENT (npx is
    // npx.cmd) and mangles paths with spaces. Invoke fmtk's CLI JS directly via node instead.
    const [tool, ...rest] = command;
    if (tool === "fmtk") {
        const fmtkCli = __ft_fileURLToPath(new URL("../factoriomod-debug/dist/fmtk-cli.js", import.meta.url));
        return runProcess(verbose, process.execPath, fmtkCli, ...rest);
    }
    return runProcess(verbose, "npx", ...command);
}
'@

if (-not $content.Contains($old)) {
  Write-Warning "Couldn't find the expected runScript() to patch (factorio-test-cli version changed?). See TESTING.md."
  return
}

Set-Content -Path $file -Value $content.Replace($old, $new) -NoNewline
Write-Host "Patched factorio-test-cli for Windows (spawn npx -> node fmtk-cli.js)."
