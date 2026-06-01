# Distrailia - Testing

Three tiers of automated checks. Two run **without Factorio** (fast, run them constantly); the
third drives a real game and runs **locally** (it needs the Space Age DLC, which can't be fetched
in public CI).

| Tier | Tool | Needs Factorio? | What it catches |
| --- | --- | --- | --- |
| Static analysis | `luacheck` | no | undefined globals, typos, unused vars, wrong load-stage API |
| Unit tests | `busted` (or a shim) | no | pure logic (e.g. the supply-area curve) |
| Integration | `factorio-test` | **yes** (local) | data stage loads; superroboport build/scale/cleanup in-game |

This guide covers **macOS, Linux, and Windows**. macOS/Linux use the standard `luarocks` toolchain
(real `busted`/`luacheck`) and `tools/run-tests.sh`. Windows can't easily build those C-dependent
rocks, so it uses a bundled `luacheck.exe` + a tiny pure-Lua shim and `tools/run-tests.ps1`.

Layout:

```
.luacheckrc                luacheck config (per-load-stage + *_spec/*_test suffix rules) [cross-platform]
.busted                    busted config                                       [cross-platform]
prototypes/entities/<feature>/   each feature co-locates its prototype(s), docs,
                                 pure logic, unit tests (*_spec.lua) and in-game
                                 tests (*_test.lua) -- e.g. prototypes/entities/superroboport/
factorio-test.example.json integration config TEMPLATE (committed)
factorio-test.json         your copy with a real factorioPath (gitignored)
package.json               dev tooling (factorio-test-cli); NOT shipped with the mod
tools/run-tests.sh         runner for macOS / Linux
tools/run-tests.ps1        runner for Windows
tools/run_specs.lua        pure-Lua busted-compatible shim (Windows / no-toolchain fallback)
tools/patch-factorio-test-cli.ps1   Windows-only CLI fix (not needed on macOS/Linux)
tools/bin/                 downloaded local binaries (gitignored): luacheck.exe (Windows)
.github/workflows/         CI (luacheck + busted on Linux)
```

---

## Quick start

**macOS / Linux**
```bash
bash tools/run-tests.sh                # luacheck + unit tests (no Factorio)
bash tools/run-tests.sh --integration  # + in-game suite (after the integration setup below)
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File tools\run-tests.ps1
powershell -ExecutionPolicy Bypass -File tools\run-tests.ps1 -Integration
```

Both print a pass/fail summary and exit non-zero on failure.

---

## Install (one-time)

Binaries/deps are kept out of git (`tools/bin/`, `node_modules/`).

### macOS
```bash
brew install lua luarocks node       # node may already be present
luarocks install luacheck busted     # real luacheck + busted (needs Xcode CLT: xcode-select --install)
```

### Linux (Debian/Ubuntu)
```bash
sudo apt install lua5.4 luarocks nodejs npm build-essential
luarocks install luacheck busted
```

### Windows
`busted`/`luacheck` rocks need a C toolchain Windows usually lacks, so:
```powershell
winget install DEVCOM.Lua            # a Lua 5.x interpreter (tools/run-tests.ps1 auto-finds common locations)
Invoke-WebRequest -UseBasicParsing `
  -Uri "https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe" `
  -OutFile "tools\bin\luacheck.exe"  # standalone luacheck, no toolchain
```
The unit tests then run via `tools/run_specs.lua` (a pure-Lua busted shim). `tools/run-tests.ps1`
looks for `lua.exe` at `C:\MY PROGRAMS\Lua\bin`, `tools\bin\lua\`, then `PATH` — adjust if needed.

### Integration runner (all OSes, only if running the in-game tier)
- **Node CLI** as a dev dependency (installs into `./node_modules`):
  ```bash
  npm install -D factorio-test-cli
  ```
- **Windows only — patch the CLI.** It does `spawn("npx", ...)` which fails on Windows
  (`spawn npx ENOENT`) and mangles paths with spaces. Re-apply after every `npm install`
  (`tools\run-tests.ps1 -Integration` does this automatically; it's idempotent):
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools\patch-factorio-test-cli.ps1
  ```
  macOS/Linux need **no** patch.
- **Config:** copy the template and set your Factorio path:
  ```bash
  cp factorio-test.example.json factorio-test.json   # Windows: Copy-Item factorio-test.example.json factorio-test.json
  ```
  Set `factorioPath` in `factorio-test.json` to your executable:
  | OS / install | factorioPath |
  | --- | --- |
  | macOS (factorio.com) | `/Applications/factorio.app/Contents/MacOS/factorio` |
  | macOS (Steam) | `~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio` |
  | Linux (standalone) | `~/factorio/bin/x64/factorio` |
  | Windows (Steam) | `C:\\...\\steamapps\\common\\Factorio\\bin\\x64\\factorio.exe` |
- **The `factorio-test` mod** is an **"internal"-category** mod → **hidden from the in-game mod
  browser**. It's a `?` optional dependency in `info.json` (normal play never loads it). Stage it
  (and `PlanetsLib`) into the isolated mods dir. Download it from the portal with the token
  Factorio already stores in `player-data.json`:

  Factorio data dir (mods + `player-data.json`): macOS `~/Library/Application Support/factorio/`,
  Linux `~/.factorio/`, Windows `%APPDATA%\Factorio\`.

  **macOS / Linux:**
  ```bash
  PD="$HOME/Library/Application Support/factorio/player-data.json"   # Linux: $HOME/.factorio/player-data.json
  MODS="$HOME/Library/Application Support/factorio/mods"             # Linux: $HOME/.factorio/mods
  user=$(node -p "require(process.argv[1])['service-username']" "$PD")
  token=$(node -p "require(process.argv[1])['service-token']" "$PD")
  mkdir -p .factorio-test-data/mods
  curl -fL -o .factorio-test-data/mods/factorio-test_3.0.1.zip \
    "https://mods.factorio.com/download/factorio-test/6976a97e25c8996413a5adac?username=$user&token=$token"
  cp "$MODS"/PlanetsLib_*.zip .factorio-test-data/mods/
  ```

  **Windows (PowerShell):**
  ```powershell
  $pd = Get-Content "$env:APPDATA\Factorio\player-data.json" -Raw | ConvertFrom-Json
  $iso = ".\.factorio-test-data\mods"; New-Item -ItemType Directory -Force $iso | Out-Null
  Invoke-WebRequest -UseBasicParsing -OutFile "$iso\factorio-test_3.0.1.zip" `
    -Uri ("https://mods.factorio.com/download/factorio-test/6976a97e25c8996413a5adac?username={0}&token={1}" -f $pd.'service-username', $pd.'service-token')
  Copy-Item (Get-ChildItem "$env:APPDATA\Factorio\mods\PlanetsLib_*.zip" | Sort-Object Name | Select-Object -Last 1).FullName $iso
  ```
  (The CLI can also auto-download `factorio-test` via your player-data, but staging it is deterministic.)

---

## Running each tier

### Static analysis
```bash
luacheck control.lua data.lua prototypes tools      # macOS/Linux
# Windows: .\tools\bin\luacheck.exe control.lua data.lua prototypes tools
```

### Unit tests
```bash
busted                                                             # macOS/Linux (reads .busted)
# Windows: & "C:\MY PROGRAMS\Lua\bin\lua.exe" tools\run_specs.lua prototypes\entities\superroboport\supply_area_spec.lua
```
(or just use the runner for your OS, which does luacheck + unit together.)

### Integration tests (local, needs Factorio + DLC)
After the integration setup above (CLI installed [+ patched on Windows], `factorio-test.json`
created with `factorioPath`, `factorio-test` + `PlanetsLib` staged in `.factorio-test-data/mods/`):

```bash
bash tools/run-tests.sh --integration        # macOS/Linux (all three tiers)
# Windows: powershell -ExecutionPolicy Bypass -File tools\run-tests.ps1 -Integration
# or directly, any OS: npm run test:integration   (= npx factorio-test run)
```

It launches Factorio **headless** (no window) on a bundled empty-lab save, builds superroboports
of various qualities, and asserts the paired hidden roboport, the per-quality supply area
(`get_supply_area_distance`), power, and cleanup; it exits non-zero on failure. `npx factorio-test
run --help` lists flags (`--game-speed`, `--test-pattern`, `-g`/`--graphics` to watch it, …).

**Why the isolated `dataDirectory`** (`./.factorio-test-data`, gitignored, set in the config): the
run never touches your live game's mods/config, and it's the only way to run while a game is open
(Factorio's single-instance lock). `base`/`space-age`/`quality`/`elevated-rails` come from the
Factorio **install** (read-data) automatically — only third-party mods (`factorio-test`,
`PlanetsLib`) need staging. *Simpler alternative:* delete the `dataDirectory` line to reuse your
normal install, at the cost of toggling your live mod list and not running alongside an open game.

---

## CI

`.github/workflows/test.yml` runs **luacheck + busted** on Linux (installs them via luarocks).
The integration tier is **not** in public CI: the mod requires the Space Age DLC, which can't be
downloaded on a hosted runner. To automate it, use a **self-hosted runner** with Factorio + the DLC
installed, then add a job invoking `factorio-test run`.

---

## Adding tests
Tests live **beside the feature** (e.g. `prototypes/entities/superroboport/`); `.luacheckrc` and the
runners pick them up by filename suffix, so location is flexible.
- **Pure logic** → a Factorio-free module co-located with the feature, plus a `<name>_spec.lua`
  beside it using `describe` / `it` / `assert.*` (luassert). Any `*_spec.lua` is run by
  `busted` / `tools/run_specs.lua` and linted with busted globals.
- **In-game behavior** → a `<name>_test.lua` beside the feature with `test(...)` blocks using plain
  `assert(cond, message)` (FactorioTest 3.x does **not** provide luassert — `assert` is Lua's
  function), and list the module in the `require("__factorio-test__/init")({ ... })` call at the
  bottom of `control.lua`.
