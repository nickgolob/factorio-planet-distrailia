# Distrailia - Dev notes

Fast iteration on the planet surface. (Install / junction setup: see `DEVINSTALL.md`.)

## Two buckets
- **map_gen value tuning** (frequency / size / richness, water, autoplace probabilities): tune live, **no restart**.
- **prototype changes** (new tiles, chasm entity, resources, named noise expressions): **restart Factorio** - the data stage only loads at startup.

## Live re-roll (no restart)
The surface keeps a mutable copy of its settings, so you can tweak a value, wipe chunks, and regenerate around spawn. Run these as separate `/c` commands (so `clear()` settles first):

```
/c local s=game.surfaces["distrailia"]; local m=s.map_gen_settings; m.autoplace_controls["iron-ore"]={frequency=0.5,size=3,richness=2}; s.map_gen_settings=m
/c game.surfaces["distrailia"].clear()
/c local s=game.surfaces["distrailia"]; s.request_to_generate_chunks({0,0},8); s.force_generate_chunk_requests(); game.player.teleport({0,0},s); game.player.force.chart(s,{{-256,-256},{256,256}})
```

Only changing resources / decoratives? Skip `clear()` and just re-roll them in place:

```
/c local s=game.surfaces["distrailia"]; s.regenerate_entity(); s.regenerate_decorative()
```

## After a prototype change (restart)
- Run with only `base` + `space-age` + `distrailia` for the fastest startup.
- Keep a test save already on Distrailia; after loading, run the generate/chart command above.
- `/editor` gives a free camera + a live map-gen panel for eyeballing layouts without editing files.

## Tests
Two suites run **without Factorio** and gate before in-game testing:
- **luacheck** - static analysis (config: `.luacheckrc`), catches undefined globals, typos,
  unused vars, wrong load-stage API use.
- **unit tests** - pure logic in `lib/` (e.g. the supply-area curve) tested in `spec/`, written
  in busted style.

Run everything locally (Windows):

```
powershell -ExecutionPolicy Bypass -File tools\run-tests.ps1
```

One-time local setup (binaries land in `tools/bin/`, which is gitignored):
- Lua: `winget install DEVCOM.Lua`
- luacheck: download `luacheck.exe` from https://github.com/lunarmodules/luacheck/releases into `tools/bin/`

How it runs: locally we use the system Lua + `tools/run_specs.lua` (a tiny busted-compatible
shim, since a full `busted` needs a C toolchain we don't have on Windows). CI
(`.github/workflows/test.yml`) runs the *same* `.luacheckrc` and `spec/` files with the canonical
`luacheck` + `busted` on Linux. Add new pure logic under `lib/` and a matching `spec/*_spec.lua`.

**Not covered by these:** anything needing the running game - the data stage actually loading, and
the `control.lua` superroboport lifecycle (build/scale/cleanup/power). Those need an in-game
harness (e.g. FactorioTest) + a Factorio binary; still verified by manual in-game testing.
