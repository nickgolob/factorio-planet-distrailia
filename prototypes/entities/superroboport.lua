-- Distrailia superroboport -- the M6 capstone reward.
--
-- Design (DESIGN.md "The reward"): a combined roboport + substation that
-- supplies a 50x50 power area, obtained at legendary quality at the top of the tech branch.
--
-- Implementation follows the confirmed "Utility Station" precedent: the visible, blueprintable
-- entity is a roboport, and a hidden, indestructible electric pole is spawned underneath it at
-- runtime (see control.lua) and removed with it. We take the quality-scaling option: the power area
-- scales with quality. Quality adds +1 to supply_area_distance per quality level and legendary
-- is level 5 (verified: small pole 2.5->7.5, substation 9->14), so a base of 20 gives 40x40 at
-- normal and lands on exactly 25 -> 50x50 at legendary. control.lua spawns the hidden pole at
-- the roboport's own quality so the two stay in lockstep.
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

-- Visible entity: a roboport with a slightly larger logistic/construction range. -----------
local entity = util.table.deepcopy(roboport_proto)
entity.name = PARENT
entity.icon = nil
entity.icon_size = nil
entity.icons = icons
entity.minable = entity.minable or { mining_time = 1 }
entity.minable.result = PARENT
entity.placeable_by = { item = PARENT, count = 1 }
-- "Large radius" per DESIGN.md "The reward". Never shrink the vanilla values, and keep the two
-- dependent fields >= logistics_radius (the engine requires it), so clamp with math.max.
entity.logistics_radius = math.max(entity.logistics_radius or 0, 32)
entity.logistics_connection_distance =
  math.max(entity.logistics_connection_distance or entity.logistics_radius, entity.logistics_radius)
entity.construction_radius = math.max(entity.construction_radius or 0, 64)
entity.next_upgrade = nil
entity.fast_replaceable_group = nil

-- Hidden substation, spawned under the roboport at runtime by control.lua. -----------------
-- Collides with nothing (it sits under the roboport), is invisible, unselectable and
-- indestructible, but keeps a substation's wire reach so it auto-joins the power grid.
local pole = util.table.deepcopy(substation_proto)
pole.name = CHILD
pole.localised_name = { "" }
pole.localised_description = { "" }
pole.supply_area_distance = 20 -- radius; quality adds +1/level -> 25 (50x50) at legendary, 40x40 at normal
pole.selectable_in_game = false
pole.collision_mask = { layers = {} }
pole.collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } }
pole.selection_box = nil
pole.icon = nil
pole.icon_size = nil
pole.icons = icons
-- An electric pole's `pictures` is a RotatedSprite (requires `direction_count`);
-- util.empty_sprite() is a plain Sprite and fails to load. Use a 1-direction empty
-- rotated sprite so the hidden pole stays invisible but valid.
pole.pictures = { filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1 }
-- The pole's wire-connection-point count must equal pictures.direction_count. The vanilla
-- substation ships 4 (one per rotation); collapse to a single point to match our 1-direction
-- empty sprite. Power still flows (grid connectivity is by wire reach, not point count) and
-- the point is never drawn (draw_copper_wires = false).
pole.connection_points = { { wire = { copper = { 0, 0 } }, shadow = { copper = { 0, 0 } } } }
pole.radius_visualisation_picture = nil
pole.draw_copper_wires = false -- power still connects logically; just no visible wire
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

data:extend({ entity, pole, item, recipe, tech })
