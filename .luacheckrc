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

-- Tests: busted-style globals (describe / it / assert / ...).
files["spec/**/*.lua"] = { std = "lua53+busted" }
