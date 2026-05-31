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
Three tiers (full install + run guide: [`TESTING.md`](TESTING.md)):
- **luacheck** (static analysis) + **unit tests** (pure logic in `lib/`, tested in `spec/`) -
  no Factorio needed. Run both:

  ```
  bash tools/run-tests.sh                 # macOS / Linux
  tools\run-tests.ps1                     # Windows (PowerShell)
  ```

- **integration** (FactorioTest, `tests/`) - drives a real game (build/scale/cleanup of the
  superroboport). Run locally: `bash tools/run-tests.sh --integration` (`-Integration` on Windows;
  or `npm run test:integration`). Needs the Space Age DLC, so it's local-only, not in public CI.

CI (`.github/workflows/test.yml`) runs luacheck + busted on Linux. Add pure logic under `lib/` +
a `spec/*_spec.lua`; add in-game behaviour under `tests/`.
