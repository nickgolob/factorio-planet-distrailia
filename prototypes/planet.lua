-- Distrailia planet definition.
--
-- M1 goal: a loadable planet, reachable late-game. We deep-copy Nauvis so the surface is
-- guaranteed to generate (all Nauvis tiles, ores, and enemies) and then apply only the
-- Distrailia M1 differences: its outermost star-map spot and 100% solar. Travel is gated
-- by the discovery technology in prototypes/technology.lua. Bespoke terrain (large lava
-- lakes, hell tiles, indestructible chasms), the new resources, enemy tuning, and custom
-- art arrive in later milestones -- see TODO.md.
--
-- Reference: https://lua-api.factorio.com/latest/prototypes/PlanetPrototype.html

local util = require("util")

local nauvis = data.raw.planet and data.raw.planet["nauvis"]
if not nauvis then
  error("[distrailia] The 'nauvis' planet prototype was not found. " ..
        "Distrailia requires the Space Age expansion (space-age).")
end

-- Planet -----------------------------------------------------------------------
local distrailia = util.table.deepcopy(nauvis)

distrailia.name = "distrailia"
distrailia.localised_name = { "space-location-name.distrailia" }
distrailia.localised_description = { "space-location-description.distrailia" }
distrailia.order = "z[distrailia]"

-- Place Distrailia as the outermost world, beyond Secretas (distance 45) and the
-- vanilla planets. A distinct orientation keeps it clear of the Secretas/Frozeta cluster.
distrailia.distance = 50
distrailia.orientation = 0.45

-- A hellscape bathed in light: full solar. (Nauvis is the 100% reference; set
-- explicitly so the intent survives future surface_property edits.)
distrailia.surface_properties = distrailia.surface_properties or {}
distrailia.surface_properties["solar-power"] = 100

-- Asteroids only on the voyage, never when parked here. Nauvis's orbit asteroids are added
-- later (space-age base-data-updates), so the deep copy carries none; make that explicit,
-- and stop the planet from seeding its connections (influence 0). The dense voyage asteroids
-- live on the connections themselves (see data-final-fixes.lua). Net effect: idling in
-- Distrailia's orbit is calm; only the trip is dangerous.
distrailia.asteroid_spawn_influence = 0
distrailia.asteroid_spawn_definitions = {}

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
-- Distrailia is a rail world: ore should sit in a few large, rich patches set far apart,
-- so expanding means laying rail to a distant outpost instead of walking next door.
-- Retune only the inherited Nauvis ore controls here (low frequency = spread out; big
-- size + richness = patches worth the haul). Bespoke resources (demonite/hellstone/souls)
-- and terrain arrive in later milestones. Dial these in live -- see DEV.md.
distrailia.map_gen_settings = distrailia.map_gen_settings or {}
distrailia.map_gen_settings.autoplace_controls = distrailia.map_gen_settings.autoplace_controls or {}
local ore_controls = distrailia.map_gen_settings.autoplace_controls

local rail_world_ore = { frequency = 0.25, size = 3, richness = 2 }
for _, ore in ipairs({ "iron-ore", "copper-ore", "coal", "stone", "uranium-ore", "crude-oil" }) do
  local control = ore_controls[ore] or {}
  control.frequency = rail_world_ore.frequency
  control.size = rail_world_ore.size
  control.richness = rail_world_ore.richness
  ore_controls[ore] = control
end

-- TODO(M5): replace the reused Nauvis icons / starmap art with bespoke Distrailia art.

data:extend({ distrailia })

-- Space connection -------------------------------------------------------------
-- A direct Nauvis -> Distrailia route, for modpacks without a space-connection manager.
-- (Some packs regenerate connections by planet distance and drop this one, linking Distrailia
-- to its distance-neighbours instead. Either way, the dense large-asteroid voyage is applied
-- in data-final-fixes.lua to whatever connections actually reach Distrailia.) Reuse an
-- existing Nauvis route for its structural fields.
local template
for _, connection in pairs(data.raw["space-connection"] or {}) do
  if connection.from == "nauvis" or connection.to == "nauvis" then
    template = connection
    break
  end
end

if not template then
  error("[distrailia] No existing Nauvis space-connection found to use as a template.")
end

local route = util.table.deepcopy(template)
route.name = "nauvis-distrailia"
route.localised_name = { "space-connection-name.nauvis-distrailia" }
route.from = "nauvis"
route.to = "distrailia"
route.length = 12000
route.order = "z[distrailia]"
-- TODO(M5): give the route its own icon (currently inherited from the template route).

-- Dense "super large" asteroids for the whole voyage to Distrailia. Reuse Space Age's own
-- asteroid generator with a custom profile: heavy on huge asteroids (peaking near the
-- densest vanilla route -- the Shattered Planet run tops out at 0.111) plus some big ones,
-- and no promethium. Density ramps up as you approach. spawn_definitions() with no planet
-- argument yields route spawns interpolated along the trip (distance 0..1); the planet's
-- own empty definitions above keep the orbit calm when idle.
local distrailia_voyage =
{
  probability_on_range_big =
  {
    { position = 0.05, probability = 0.02, angle_when_stopped = asteroid_util.big_angle },
    { position = 0.95, probability = 0.04, angle_when_stopped = asteroid_util.big_angle },
  },
  probability_on_range_huge =
  {
    { position = 0.05, probability = 0.03, angle_when_stopped = asteroid_util.huge_angle },
    { position = 0.50, probability = 0.07, angle_when_stopped = asteroid_util.huge_angle },
    { position = 0.95, probability = 0.11, angle_when_stopped = asteroid_util.huge_angle },
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
