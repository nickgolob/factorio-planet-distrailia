-- Distrailia discovery technology.
--
-- Adding a technology with an "unlock-space-location" effect makes the planet locked
-- until researched: it stays visible on the star map (like the vanilla planets before
-- their discovery tech) but cannot be travelled to. We chain off the Aquilo discovery so
-- it sits late in the tree, and charge 2000 cryogenic science packs.
--
-- The tech name matches the locale keys in locale/en/distrailia.cfg
-- (technology-{name,description}.planet-discovery-distrailia), so the localised strings
-- resolve by default and we don't set localised_name/localised_description explicitly.
--
-- Reference: https://lua-api.factorio.com/latest/types/UnlockSpaceLocationModifier.html

local util = require("util")

local planet = data.raw.planet and data.raw.planet["distrailia"]
if not planet then
  error("[distrailia] planet prototype missing; technology.lua must load after planet.lua.")
end

-- Find the technology that discovers a given space location (e.g. Aquilo) so we can chain
-- off it and sit "after Aquilo" in the tech tree without hard-coding a vanilla tech name.
local function discovery_tech_for(location)
  for name, tech in pairs(data.raw.technology) do
    if tech.effects then
      for _, effect in pairs(tech.effects) do
        if effect.type == "unlock-space-location" and effect.space_location == location then
          return name
        end
      end
    end
  end
  return nil
end

-- Prerequisites: discover Aquilo first, and (if present) require the cryogenic science
-- pack tech so this never appears researchable before the player can produce its cost.
local prerequisites = {}
local aquilo_tech = discovery_tech_for("aquilo")
if aquilo_tech then
  table.insert(prerequisites, aquilo_tech)
end
if data.raw.technology["cryogenic-science-pack"] then
  table.insert(prerequisites, "cryogenic-science-pack")
end

local tech = {
  type = "technology",
  name = "planet-discovery-distrailia",
  effects = {
    { type = "unlock-space-location", space_location = "distrailia", use_icon_overlay_constant = true },
  },
  prerequisites = prerequisites,
  unit = {
    count = 2000,
    ingredients = { { "cryogenic-science-pack", 1 } },
    time = 60,
  },
  order = "z-[distrailia]",
}

-- Reuse the planet's art for the tech icon (currently placeholder Nauvis art; M5 replaces it).
if planet.icons then
  tech.icons = util.table.deepcopy(planet.icons)
elseif planet.icon then
  tech.icon = planet.icon
  tech.icon_size = planet.icon_size or 64
elseif planet.starmap_icon then
  tech.icon = planet.starmap_icon
  tech.icon_size = planet.starmap_icon_size or 512
else
  error("[distrailia] Could not derive a tech icon from the planet prototype.")
end

data:extend({ tech })
