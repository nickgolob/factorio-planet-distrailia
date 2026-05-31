-- Distrailia planet definition.
--
-- We deep-copy Nauvis so the surface is guaranteed to generate (all Nauvis tiles, ores, and
-- enemies), then apply the Distrailia differences (outermost star-map spot, 100% solar,
-- rail-world ore spacing). Placement goes through PlanetsLib so Distrailia joins the shared
-- orbit tree like the pack's other planets: orbiting "star" puts it at the same absolute
-- distance/orientation it used before, but now orbit-aware mods move it with its parent and
-- treat it consistently. PlanetsLib: Tiers, if installed, gets a tier value so tier-aware
-- mods order Distrailia at the post-endgame far edge. Travel is gated by the discovery
-- technology in prototypes/technology.lua. Bespoke terrain, new resources, enemy tuning, and
-- custom art arrive in later milestones -- see TODO.md.
--
-- Refs: PlanetsLib README "Defining planets";
--       https://lua-api.factorio.com/latest/prototypes/PlanetPrototype.html

local util = require("util")
-- Space Age's own asteroid spawn generator (cache-warm: space-age is a hard dependency, so it
-- has already required this module by the time our data stage runs). Used by the dense voyage
-- asteroid profile applied to the Nauvis->Distrailia connection below.
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")

local nauvis = data.raw.planet and data.raw.planet["nauvis"]
if not nauvis then
  error("[distrailia] The 'nauvis' planet prototype was not found. " ..
        "Distrailia requires the Space Age expansion (space-age).")
end

if not PlanetsLib then
  error("[distrailia] PlanetsLib was not found. Distrailia depends on PlanetsLib for " ..
        "star-map placement (see info.json).")
end

-- Planet -----------------------------------------------------------------------
local distrailia = util.table.deepcopy(nauvis)

distrailia.name = "distrailia"
distrailia.localised_name = { "space-location-name.distrailia" }
distrailia.localised_description = { "space-location-description.distrailia" }
distrailia.order = "z[distrailia]"

-- Placement is via PlanetsLib's orbit, set just before PlanetsLib:extend below. The planet
-- must NOT carry top-level distance/orientation when passed to extend (PlanetsLib errors).

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

-- Outermost world, beyond Secretas (distance 45). Orbit "star" directly so the absolute
-- position equals the orbit's (distance 50, orientation 0.45) -- the same spot used before the
-- PlanetsLib refactor. A distinct orientation keeps it clear of the Secretas/Frozeta cluster.
-- Strip any distance/orientation/position carried over from the Nauvis copy first, since
-- PlanetsLib:extend rejects top-level distance/orientation.
distrailia.distance = nil
distrailia.orientation = nil
distrailia.position = nil
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
