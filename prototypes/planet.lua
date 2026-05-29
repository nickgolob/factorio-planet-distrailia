-- Distrailia planet definition.
--
-- M1 goal: a loadable planet, reachable late-game. We deep-copy Nauvis so the surface is
-- guaranteed to generate (all Nauvis tiles, ores, and enemies) and then apply only the
-- Distrailia M1 differences: its outermost star-map spot and 100% solar. Travel is gated
-- by the discovery technology in prototypes/technology.lua. Bespoke terrain (large lava
-- lakes, hell tiles, indestructible chasms), the new resources, enemy tuning, and custom
-- art arrive in later milestones -- see PLAN.md.
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

-- TODO(M5): replace the reused Nauvis icons / starmap art with bespoke Distrailia art.

data:extend({ distrailia })

-- Space connection -------------------------------------------------------------
-- Reuse an existing Nauvis route so we inherit working asteroid spawn definitions
-- rather than guessing required fields.
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

data:extend({ route })
