-- Static-analysis config for the Distrailia mod.
--
-- Run via tools/run-tests.ps1 (uses the bundled tools/bin/luacheck.exe), or `luacheck .`
-- on any machine/CI with luacheck installed.
--
-- Factorio runs a Lua 5.2 VM; we use a permissive base std plus the engine-provided
-- globals, scoped per load stage so e.g. a control-stage global referenced from the data
-- stage (or vice versa) is flagged as undefined.

std = "lua53"
max_line_length = false -- comments carry reference URLs; line length isn't a bug class
codes = true
quiet = 1

-- Never lint downloaded tooling, generated dirs, or VCS internals.
exclude_files = {
  "tools/bin",
  ".git",
}

-- Globals present in (essentially) every Factorio Lua context, plus library mods we depend
-- on that inject globals (PlanetsLib -- star-map placement, used in prototypes/planet.lua).
read_globals = {
  "defines",
  "mods",
  "settings",
  "table_size",
  "log",
  "localised_print",
  "serpent",
  "PlanetsLib",
}

-- Data stage: the `data` table is read and mutated.
local data_stage = { globals = { "data" } }
files["data.lua"] = data_stage
files["data-updates.lua"] = data_stage
files["data-final-fixes.lua"] = data_stage
files["settings.lua"] = data_stage
files["settings-updates.lua"] = data_stage
files["settings-final-fixes.lua"] = data_stage
files["prototypes/**/*.lua"] = data_stage

-- Control stage: runtime globals.
local control_stage = {
  globals = { "storage" },
  read_globals = { "game", "script", "rendering", "rcon", "commands", "remote", "prototypes", "helpers" },
}
files["control.lua"] = control_stage
files["scripts/**/*.lua"] = control_stage
-- Visual-test infrastructure (framework + helpers) runs in the control stage (game/rendering/...).
files["visual_tests/**/*.lua"] = control_stage
-- Feature-specific visual scenes are control-stage too, despite living under prototypes/. Spell the
-- path out so it out-ranks the data-stage `prototypes/**/*.lua` glob below.
files["prototypes/entities/superroboport/visual.lua"] = control_stage

-- Test files co-locate with their feature (e.g. prototypes/entities/superroboport/). luacheck applies
-- the SINGLE most-specific matching `files` pattern, so each suffix glob below is ALSO spelled out per
-- feature dir to out-rank the data-stage `prototypes/**/*.lua` glob above for those co-located tests.

-- Unit tests (pure logic): busted-style globals.
local busted_std = { std = "lua53+busted" }
files["**/*_spec.lua"] = busted_std
files["prototypes/entities/superroboport/*_spec.lua"] = busted_std

-- Integration tests run in the control stage under FactorioTest, which injects its own test globals
-- (test / async / after_ticks / ...) on top of the runtime API.
local factorio_test = {
  std = "lua53", -- FactorioTest does NOT replace global `assert`; tests use plain assert(cond, msg)
  read_globals = { "game", "script", "rendering", "commands", "remote", "prototypes", "helpers", "storage" },
  globals = {
    -- FactorioTest-provided globals.
    "test", "it", "describe",
    "before_all", "after_all", "before_each", "after_each", "after_test",
    "async", "done", "on_tick", "after_ticks", "ticks_between_tests", "tags",
  },
}
files["**/*_test.lua"] = factorio_test
files["prototypes/entities/superroboport/*_test.lua"] = factorio_test
