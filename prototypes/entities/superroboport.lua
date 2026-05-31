-- Distrailia superroboport -- the M6 capstone reward.
--
-- Design (DESIGN.md "The reward"): a combined roboport + substation that
-- supplies a 50x50 power area, obtained at legendary quality at the top of the tech branch.
--
-- Implementation follows the confirmed "Utility Station" precedent: the visible, blueprintable
-- entity is a roboport, and a hidden electric pole sits underneath it (spawned at runtime by
-- control.lua and removed with it) to supply power. The pole is selectable -- but not minable or
-- deconstructable -- so you can hover its centre to see the blue supply-area square and click it
-- to open the electric-network GUI, exactly like any pole. It keeps a substation's wire reach so
-- it auto-joins the power grid.
--
-- The power area scales with quality. The engine's built-in pole bonus is a flat +1 to
-- supply_area_distance per quality level, which could only span 40x40->50x50 -- a dull spread --
-- so instead we define one hidden-pole variant per quality with an explicit supply_area_distance,
-- spaced evenly across the quality tiers from a 30x30 floor (normal) to exactly 50x50 (legendary).
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
local supply_area = require("lib.supply_area")

local PARENT = "superroboport"
local CHILD = "superroboport-substation"

local roboport_proto = data.raw.roboport and data.raw.roboport["roboport"]
local substation_proto = data.raw["electric-pole"] and data.raw["electric-pole"]["substation"]
if not roboport_proto then
  error("[distrailia] base 'roboport' prototype not found; superroboport requires base + space-age.")
end
if not substation_proto then
  error("[distrailia] base 'substation' prototype not found; superroboport requires base + space-age.")
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

-- Hidden substation template, spawned under the roboport at runtime by control.lua. ---------
-- Collides with nothing (it sits under the roboport) and is invisible, but is SELECTABLE (and
-- indestructible / not minable) so you can hover its centre to see the blue supply-area square
-- and click it to open the electric-network GUI, like any pole. Keeps a substation's wire reach
-- so it auto-joins the power grid. supply_area_distance is set per quality variant below.
local pole = util.table.deepcopy(substation_proto)
pole.name = CHILD
pole.localised_name = { "entity-name." .. PARENT }
pole.localised_description = { "entity-description." .. PARENT }
pole.selectable_in_game = true
pole.collision_mask = { layers = {} }
pole.collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } }
pole.selection_box = { { -1, -1 }, { 1, 1 } } -- small centre target; the roboport (4x4) owns the rest
-- Win the cursor over the roboport on that centre tile (both otherwise default to 50) so hovering
-- the centre shows the blue supply-area square and clicking it opens the electric-network GUI.
pole.selection_priority = 100
pole.icon = nil
pole.icon_size = nil
pole.icons = icons
-- An electric pole's `pictures` is a RotatedSprite (requires `direction_count`);
-- util.empty_sprite() is a plain Sprite and fails to load. Use a 1-direction empty
-- rotated sprite so the hidden pole stays invisible but valid.
pole.pictures = { filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1 }
-- The pole's wire-connection-point count must equal pictures.direction_count. The vanilla
-- substation ships 4 (one per rotation); collapse to a single point to match our 1-direction
-- empty sprite. Connectivity is by wire reach (not point count); the wire attaches at the centre.
pole.connection_points = { { wire = { copper = { 0, 0 } }, shadow = { copper = { 0, 0 } } } }
pole.radius_visualisation_picture = nil
-- Show the copper wires so the superroboport is visibly part of the power grid. (It auto-connects
-- either way -- draw_copper_wires only controls the graphic -- but hiding them made it look unpowered.)
pole.draw_copper_wires = true
pole.draw_circuit_wires = false
pole.circuit_wire_max_distance = 0 -- no circuit-network hookups on the hidden pole
pole.next_upgrade = nil
pole.fast_replaceable_group = nil
pole.minable = nil
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

-- One hidden-pole variant per quality, each with an explicit supply_area_distance so we own the
-- curve (the engine's built-in +1/level only spans 40x40->50x50). Spaced evenly across the
-- quality TIERS from a 30x30 floor (normal) to exactly 50x50 (legendary) -- i.e. by sorted rank,
-- not by raw level (legendary is level 5, skipping 4, so scaling by level would leave an uneven
-- jump at the top). control.lua spawns the variant named "<CHILD>-<quality>" at normal quality.
local FLOOR_RADIUS = 15 -- normal -> 30x30
local CAP_RADIUS = 25   -- legendary -> 50x50

-- Sort the (non-hidden) qualities low -> high, then ask the pure curve module for an evenly
-- spaced supply-area radius per tier. The arithmetic lives in lib/supply_area.lua so it can be
-- unit-tested (spec/supply_area_spec.lua); here we only feed it the quality tier names.
local qualities = {}
for _, q in pairs(data.raw.quality or {}) do
  if not q.hidden then qualities[#qualities + 1] = q end
end
table.sort(qualities, function(a, b) return (a.level or 0) < (b.level or 0) end)

local sorted_names = {}
for i, q in ipairs(qualities) do sorted_names[i] = q.name end
local radius_by_quality = supply_area.curve(sorted_names, FLOOR_RADIUS, CAP_RADIUS)

local pole_variants = {}
for _, q in ipairs(qualities) do
  local variant = util.table.deepcopy(pole)
  variant.name = CHILD .. "-" .. q.name
  variant.supply_area_distance = radius_by_quality[q.name]
  pole_variants[#pole_variants + 1] = variant
end

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

local protos = { entity, item, recipe, tech }
for _, variant in pairs(pole_variants) do
  protos[#protos + 1] = variant
end
data:extend(protos)
