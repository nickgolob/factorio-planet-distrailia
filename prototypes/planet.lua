-- Distrailia planet definition.
--
-- Authored from scratch (no Nauvis copy): the planet prototype and its map generation are
-- defined explicitly, following the majority pattern of the pack's other planet mods (an
-- authored `type="planet"` prototype + a map_gen_settings built on Wube's planet-map-gen
-- helper). The map generation (desert land, water + lava lakes, Nauvis ores) lives in
-- prototypes/planet/map-gen.lua.
--
-- Placement goes through PlanetsLib so Distrailia joins the shared orbit tree: orbiting "star"
-- at distance 50 / orientation 0.45 puts it at the outermost slot beyond Secretas, and
-- orbit-aware mods treat it consistently. PlanetsLib: Tiers, if installed, gets a tier value so
-- tier-aware mods order it at the post-endgame far edge. Travel is gated by the discovery
-- technology in prototypes/technology.lua.
--
-- Icons are vanilla PLACEHOLDERS until bespoke art lands in M5. Bespoke tiles, new resources
-- (M3), enemy tuning (M2), and chasms arrive in later milestones -- see TODO.md.
--
-- Refs: PlanetsLib README "Defining planets";
--       https://lua-api.factorio.com/latest/prototypes/PlanetPrototype.html
--       __space-age__/prototypes/planet/planet.lua (vanilla planet prototype shape)

local util = require("util")
local planet_map_gen = require("prototypes.planet.map-gen")
-- Space Age's own asteroid spawn generator (cache-warm: space-age is a hard dependency, so it
-- has already required this module by the time our data stage runs). Used by the dense voyage
-- asteroid profile applied to the Nauvis->Distrailia connection below.
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

if not PlanetsLib then
  error("[distrailia] PlanetsLib was not found. Distrailia depends on PlanetsLib for " ..
        "star-map placement (see info.json).")
end

-- Planet -----------------------------------------------------------------------
-- Authored explicitly. Icons are PLACEHOLDERS (vanilla Nauvis art) until bespoke art lands in
-- M5. surface_properties: 100% solar per DESIGN.md (a hellscape bathed in light); gravity and
-- pressure are first-pass placeholders matching Nauvis -- tune later. Map generation comes from
-- prototypes/planet/map-gen.lua.
local distrailia =
{
  type = "planet",
  name = "distrailia",
  localised_name = { "space-location-name.distrailia" },
  localised_description = { "space-location-description.distrailia" },
  icon = "__base__/graphics/icons/nauvis.png", -- TODO(M5): bespoke Distrailia icon
  icon_size = 64,
  starmap_icon = "__base__/graphics/icons/starmap-planet-nauvis.png", -- TODO(M5): bespoke starmap art
  starmap_icon_size = 512,
  gravity_pull = 10, -- placeholder (Nauvis = 10); tune later
  order = "z[distrailia]",
  subgroup = "planets",
  map_gen_settings = planet_map_gen.distrailia(),
  surface_properties =
  {
    ["solar-power"] = 100, -- a hellscape bathed in light (DESIGN.md)
    ["pressure"] = 1000,   -- placeholder (Nauvis reference); tune later
    ["gravity"] = 9.81,    -- placeholder (Nauvis reference); tune later
  },
  -- Asteroids only on the voyage, never when parked here: empty definitions + influence 0 keep
  -- the orbit calm. The dense voyage asteroids live on the connection below. Net effect: idling
  -- in Distrailia's orbit is calm; only the trip is dangerous.
  asteroid_spawn_influence = 0,
  asteroid_spawn_definitions = {},
}

-- Mod compat: "Redrawn Space Connections" rebuilds the entire connection graph in
-- data-final-fixes, deriving each route's asteroids by interpolating the two endpoints'
-- *planet* asteroid_spawn_definitions. That deletes our hand-built route and, because our
-- orbit is intentionally empty, leaves the trip with only faint medium asteroids. Excluding
-- Distrailia makes RSC keep our bespoke Nauvis->Distrailia route (dense huge asteroids) and
-- not auto-wire the planet. The field is ignored when RSC isn't installed; guard anyway.
if mods["Redrawn-Space-Connections"] then
  distrailia.redrawn_connections_exclude = true
end

-- Rail-world resource spacing --------------------------------------------------
-- Distrailia is a rail world: patches spread far apart with lots of empty ground between
-- them, so expanding means laying rail to a distant outpost. FREQUENCY is the spacing
-- lever (lower = fewer, more separated patches). Keep SIZE ~1: enlarging patches just
-- fills the gaps back in and fights the sparseness. RICHNESS is pushed up so the few
-- distant patches are still worth hauling. Retunes the Nauvis ore controls;
-- bespoke resources (demonite/hellstone/souls) and terrain arrive in later milestones.
-- NOTE: near the landing/origin the starting-area guarantee still seeds starter patches
-- regardless of frequency -- judge sparseness away from spawn. Dial live -- see DEV.md.
local ore_controls = distrailia.map_gen_settings.autoplace_controls

local rail_world_ore = { frequency = 0.2, size = 1, richness = 3 }
for _, ore in ipairs({ "iron-ore", "copper-ore", "coal", "stone", "uranium-ore", "crude-oil" }) do
  local control = ore_controls[ore] or {}
  control.frequency = rail_world_ore.frequency
  control.size = rail_world_ore.size
  control.richness = rail_world_ore.richness
  ore_controls[ore] = control
end

-- Outermost world, beyond Secretas (distance 45). Orbit "star" directly so the absolute
-- position is the orbit's (distance 50, orientation 0.45). A distinct orientation keeps it
-- clear of the Secretas/Frozeta cluster. PlanetsLib:extend rejects top-level
-- distance/orientation, so placement is expressed purely as the orbit below.
distrailia.orbit = {
  parent = { type = "space-location", name = "star" },
  distance = 50,
  orientation = 0.45,
}
PlanetsLib:extend(distrailia)

-- PlanetsLib: Tiers (optional). Distrailia isn't in the central tier list, so without this it
-- falls back to the default (~3.33) and tier-aware mods mis-order it. As the outermost,
-- post-Aquilo hellscape it sits past Secretas (5.6) and panglia (5.7), so register it as a
-- post-endgame tier. Guarded: only runs when Tiers is installed (it owns this mod-data).
local tierlist = data.raw["mod-data"] and data.raw["mod-data"]["PlanetsLib-tierlist"]
if tierlist and tierlist.data and tierlist.data.planet then
  tierlist.data.planet["distrailia"] = 6
end

-- Space connection -------------------------------------------------------------
-- A direct Nauvis -> Distrailia route carrying the dense large-asteroid voyage profile built
-- below. Reuse an existing Nauvis route for its structural fields. A connection manager such
-- as Redrawn Space Connections would otherwise delete and regenerate this route (discarding
-- our asteroid profile), so we flag the planet and the route to be kept as-is (see the
-- "Redrawn Space Connections" notes above and below).
local template
for _, connection in pairs(data.raw["space-connection"] or {}) do
  if connection.from == "nauvis" or connection.to == "nauvis" then
    template = connection
    break
  end
end

if not template then
  error("[distrailia] No existing Nauvis space-connection found to use as a template. " ..
        "Distrailia requires the Space Age expansion (space-age).")
end

local route = util.table.deepcopy(template)
route.name = "nauvis-distrailia"
route.localised_name = { "space-connection-name.nauvis-distrailia" }
route.from = "nauvis"
route.to = "distrailia"
route.length = 12000
route.order = "z[distrailia]"
-- TODO(M5): give the route its own icon (currently inherited from the template route).

-- Voyage asteroids, tuned to sit a touch above Frozeta's route (Secretas mod "aquilo_secretas"
-- profile, the reference point: big peaks ~0.0025 then fades, huge rises to ~0.00125 on
-- approach). Distrailia leans into HUGE asteroids as its signature, so huge ramps up to ~0.0018
-- near the planet (~1.4x Frozeta's huge) while big stays light and flat. No promethium.
-- These are the live-tuning knobs: nudge the probabilities up/down to taste (needs a Factorio
-- restart -- this is data stage). spawn_definitions() with no planet argument yields route
-- spawns interpolated along the trip (distance 0..1); the planet's own empty definitions above
-- keep the orbit calm when idle.
local distrailia_voyage =
{
  probability_on_range_big =
  {
    { position = 0.05, probability = 0.0008, angle_when_stopped = asteroid_util.big_angle },
    { position = 0.95, probability = 0.0008, angle_when_stopped = asteroid_util.big_angle },
  },
  probability_on_range_huge =
  {
    { position = 0.05, probability = 0.0006, angle_when_stopped = asteroid_util.huge_angle },
    { position = 0.95, probability = 0.0018, angle_when_stopped = asteroid_util.huge_angle },
  },
  type_ratios =
  {
    { position = 0.05, ratios = asteroid_util.system_edge_ratio },
    { position = 0.95, ratios = asteroid_util.system_edge_ratio },
  },
}
route.asteroid_spawn_definitions = asteroid_util.spawn_definitions(distrailia_voyage)

-- See the Redrawn Space Connections note above: also flag the connection itself so RSC keeps
-- it verbatim (with these asteroid definitions) instead of regenerating it.
if mods["Redrawn-Space-Connections"] then
  route.redrawn_connections_keep = true
end

data:extend({ route })
