-- Distrailia superroboport -- the M6 capstone reward.
--
-- Design (DESIGN.md "The reward"): a combined roboport + substation that
-- supplies a 50x50 power area, obtained at legendary quality at the top of the tech branch.
--
-- Implementation follows the confirmed "Utility Station" precedent: the blueprintable entity is a
-- roboport, and a real electric pole rises from its centre (spawned at runtime by control.lua and
-- removed with it) to supply power. The pole is selectable -- but not minable or deconstructable --
-- so you can hover it to see the blue supply-area square and click it to open the electric-network
-- GUI, exactly like any pole, and its copper wires visibly link it into your grid.
--
-- The power area scales with quality. The engine's built-in pole bonus is a flat +1 to
-- supply_area_distance per quality level, which could only span 40x40->50x50 -- a dull spread --
-- so instead we define one hidden-pole variant per quality with an explicit supply_area_distance,
-- spaced evenly across the quality tiers from a 30x30 floor (normal) to exactly 50x50 (legendary).
-- Those variants are generated in data-final-fixes.lua -- quality prototypes (data.raw.quality)
-- are NOT yet populated during the data stage, so this file only defines the base template.
-- control.lua spawns the variant matching the roboport's quality (at normal quality, no extra bonus).
--
-- TODO(M3): re-point the recipe ingredients and the technology cost/prerequisites onto the
-- Distrailia resource chain (demonite + Distrailia science) and finalise the legendary-only
-- gating once that chain exists. Until then we gate behind actually reaching Distrailia plus
-- vanilla endgame techs, with placeholder ingredients, so the mod stays loadable and the
-- reward is testable today.
--
-- References:
--   ElectricPolePrototype (supply_area_distance, max 64): https://lua-api.factorio.com/latest/prototypes/ElectricPolePrototype.html
--   RoboportPrototype (logistics_radius / construction_radius): https://lua-api.factorio.com/latest/prototypes/RoboportPrototype.html
--   Utility Station precedent: https://github.com/dmikalova/factorio-mods/tree/main/utility-station

local util = require("util")

local PARENT = "superroboport"
local CHILD = "superroboport-substation"

local roboport_proto = data.raw.roboport and data.raw.roboport["roboport"]
-- Reuse a real, tall pole's graphics + wire-connection points so the power pole is visible rising
-- from the roboport's centre and copper wires attach at its top.
local pole_source = data.raw["electric-pole"] and data.raw["electric-pole"]["big-electric-pole"]
if not roboport_proto then
  error("[distrailia] base 'roboport' prototype not found; superroboport requires base + space-age.")
end
if not pole_source then
  error("[distrailia] base 'big-electric-pole' prototype not found; superroboport requires base.")
end

-- Shared placeholder icon: a roboport with a small substation badge (M5 replaces with art).
local icons = {
  { icon = "__base__/graphics/icons/roboport.png", icon_size = 64 },
  { icon = "__base__/graphics/icons/substation.png", icon_size = 64, scale = 0.5, shift = { 10, 10 } },
}

-- Visible entity: a standard roboport (vanilla coverage). ----------------------------------
local entity = util.table.deepcopy(roboport_proto)
entity.name = PARENT
entity.icon = nil
entity.icon_size = nil
entity.icons = icons
entity.minable = entity.minable or { mining_time = 1 }
entity.minable.result = PARENT
entity.placeable_by = { item = PARENT, count = 1 }
-- Keep vanilla roboport coverage so its logistic area stays the standard 50x50 -- the footprint
-- the power supply area grows to match at legendary.
entity.next_upgrade = nil
entity.fast_replaceable_group = nil

-- Power-pole template under the roboport: a real, VISIBLE electric pole that rises from the centre
-- (the "power pole extending up in the middle"). We keep big-electric-pole's pictures and its
-- connection points untouched, so the pole is drawn and copper wires attach at its top and are
-- clearly visible -- this also avoids the earlier empty-sprite / connection-point hack entirely.
-- It is selectable (hover -> blue supply-area square; click -> electric-network GUI) but
-- indestructible / not minable. data-final-fixes.lua deep-copies this once per quality (setting the
-- per-tier supply_area_distance); control.lua spawns the matching variant under each roboport.
local pole = util.table.deepcopy(pole_source)
pole.name = CHILD
pole.localised_name = { "entity-name." .. PARENT }
pole.localised_description = { "entity-description." .. PARENT }
pole.supply_area_distance = 15 -- placeholder; data-final-fixes sets the real per-quality value (30x30..50x50)
pole.maximum_wire_distance = 30 -- placeholder; data-final-fixes sets the real per-quality reach (30 up to 50 at legendary)
pole.selectable_in_game = true
-- Win the cursor over the roboport where the pole overlaps it, so hovering the pole shows the blue
-- supply-area square and clicking it opens the electric-network GUI (both otherwise default to 50).
pole.selection_priority = 100
pole.collision_mask = { layers = {} } -- collide with nothing: it sits inside the roboport's footprint
pole.collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } }
pole.draw_copper_wires = true  -- show the wires linking it into the power grid
pole.draw_circuit_wires = false
pole.circuit_wire_max_distance = 0 -- no circuit-network hookups
pole.icon = nil
pole.icon_size = nil
pole.icons = icons
pole.minable = nil
pole.next_upgrade = nil
pole.fast_replaceable_group = nil
pole.flags = {
  "placeable-off-grid",
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-upgradable",
  "not-flammable",
  "not-in-kill-statistics",
  "hide-alt-info",
}

-- The per-quality variants of this template are generated in data-final-fixes.lua (see the note
-- near the top): quality prototypes are not populated yet during the data stage.

-- Item -------------------------------------------------------------------------------------
local item = util.table.deepcopy(data.raw.item["roboport"])
item.name = PARENT
item.icon = nil
item.icon_size = nil
item.icons = icons
item.place_result = PARENT
item.order = "c[roboport]-b[" .. PARENT .. "]"

-- Recipe (unlocked by the technology below). -----------------------------------------------
-- TODO(M3): swap these placeholder ingredients for the Distrailia chain (demonite + the
-- stable on-site intermediates) once the resource chain lands.
local recipe = {
  type = "recipe",
  name = PARENT,
  enabled = false,
  energy_required = 30,
  ingredients = {
    { type = "item", name = "roboport", amount = 1 },
    { type = "item", name = "substation", amount = 1 },
    { type = "item", name = "processing-unit", amount = 100 },
    { type = "item", name = "low-density-structure", amount = 50 },
  },
  results = { { type = "item", name = PARENT, amount = 1 } },
  icons = icons,
}

-- Technology: capstone reward. -------------------------------------------------------------
-- The broader Distrailia science branch (M3) will live in prototypes/technology.lua; this
-- tech is kept beside the reward it unlocks. TODO(M3): re-point prerequisites/cost onto the
-- Distrailia science pack and the rest of the branch.
local prerequisites = {}
local function add_prereq(name)
  if data.raw.technology[name] then table.insert(prerequisites, name) end
end
add_prereq("planet-discovery-distrailia") -- gate behind actually reaching Distrailia
add_prereq("logistic-system")
add_prereq("electric-energy-distribution-2")

local tech = {
  type = "technology",
  name = PARENT,
  icons = {
    { icon = "__base__/graphics/technology/logistic-robotics.png", icon_size = 256 },
    {
      icon = "__base__/graphics/technology/electric-energy-distribution-2.png",
      icon_size = 256,
      scale = 0.5,
      shift = { 50, 50 },
    },
  },
  effects = { { type = "unlock-recipe", recipe = PARENT } },
  prerequisites = prerequisites,
  unit = {
    count = 500,
    ingredients = { { "cryogenic-science-pack", 1 } }, -- TODO(M3): Distrailia science pack
    time = 60,
  },
  order = "z-[" .. PARENT .. "]",
}

data:extend({ entity, item, recipe, tech, pole })
