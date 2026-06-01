-- Distrailia superroboport -- the M6 capstone reward. Requirements: REQUIREMENTS.md (authoritative).
--
-- Architecture mirrors Space Exploration's Construction Pylon (read from SE 0.7.56:
-- prototypes/phase-1/entity/pylons.lua + scripts/composites.lua). The composite is TWO entities:
--
--   * "superroboport"          -- type electric-pole; the PLACED item. It carries the visible
--                                 roboport BUILDING sprite, distributes power (supply area), and
--                                 wires into the grid. Being a pole, the build cursor natively
--                                 previews the supply (power) area + the copper-wire connections,
--                                 and (preview == build) since the engine scales both by quality.
--   * "superroboport-roboport" -- type roboport; spawned under the pole by control.lua. hidden +
--                                 not selectable, its `base` blanked (the pole draws the building),
--                                 it provides the bots and draws the construction/logistic radius.
--
-- The placed pole wears a CUSTOM MERGED sprite (built below): the roboport base + a medium-electric-
-- pole mast composited rising from its centre, so the cursor previews a roboport-with-a-pole and the
-- placed result matches. NOTE the engine limit: an electric-pole cursor draws the supply area + copper
-- cables but NOT the roboport construction/logistic squares (those appear once placed) -- same ceiling
-- as SE's pylon. The visual suite's 00-build-preview golden shows exactly this.
--
-- Quality: the pole is placed at the crafted quality, so the engine's electric-pole supply-area
-- bonus (+1/level) runs 40x40 (normal) -> exactly 50x50 (legendary). Wire reach is a constant 50.
-- (30x30 floor would need per-quality prototypes spawned at normal quality, which breaks
-- preview==build, so we use 40x40 -- "acceptable" per superroboport.md.)

local util = require("util")

local PARENT = "superroboport"         -- the placed pole (the item's place_result)
local CHILD = "superroboport-roboport" -- the hidden roboport spawned underneath it

local roboport_proto = data.raw.roboport and data.raw.roboport["roboport"]
local pole_source = data.raw["electric-pole"] and data.raw["electric-pole"]["big-electric-pole"]
if not roboport_proto then
  error("[distrailia] base 'roboport' prototype not found; superroboport requires base + space-age.")
end
if not pole_source then
  error("[distrailia] base 'big-electric-pole' prototype not found; superroboport requires base.")
end

-- SE-style blank image, used to hide the roboport half's building (the pole draws it instead).
local blank = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
  frame_count = 1,
  direction_count = 1,
  line_length = 1,
  shift = { 0, 0 },
}

local icons = {
  { icon = "__base__/graphics/icons/roboport.png", icon_size = 64 },
  { icon = "__base__/graphics/icons/substation.png", icon_size = 64, scale = 0.5, shift = { 10, 10 } },
}

-- The placed entity's picture = the roboport BUILDING with a power-pole MAST rising from its centre
-- (REQUIREMENTS: "visible power pole rising from the centre of the roboport"). We composite the
-- vanilla roboport base + a medium-electric-pole mast (shifted up) into one layered RotatedSprite, so
-- the cursor previews a roboport-with-a-pole and the placed result matches exactly.
local mast_source = data.raw["electric-pole"]["medium-electric-pole"]
if not mast_source then
  error("[distrailia] base 'medium-electric-pole' prototype not found; superroboport requires base.")
end

-- Flatten a Sprite/RotatedSprite into 1-direction layers (the roboport doesn't rotate), optionally
-- dropping shadow layers and shifting every layer by (dx, dy) tiles.
local function flatten(spr, dx, dy, drop_shadow)
  local out = {}
  local function add(layer)
    if drop_shadow and layer.draw_as_shadow then return end
    local l = util.table.deepcopy(layer)
    l.direction_count = 1
    local sh = l.shift or { 0, 0 }
    l.shift = { (sh.x or sh[1] or 0) + (dx or 0), (sh.y or sh[2] or 0) + (dy or 0) }
    out[#out + 1] = l
  end
  if spr.layers then for _, layer in pairs(spr.layers) do add(layer) end else add(spr) end
  return out
end

local MAST_RISE = 1.6 -- tiles to lift the mast so it reads as rising out of the roboport's centre
local building = { layers = {} }
for _, l in ipairs(flatten(roboport_proto.base, 0, 0, false)) do table.insert(building.layers, l) end
for _, l in ipairs(flatten(mast_source.pictures, 0, -MAST_RISE, true)) do table.insert(building.layers, l) end

-- Placed entity: a pole wearing the roboport building. Pole-native cursor previews (power area +
-- copper cables); preview == build. -------------------------------------------------------------
local pole = util.table.deepcopy(pole_source)
pole.name = PARENT
pole.icon = nil
pole.icon_size = nil
pole.icons = icons
pole.localised_name = { "entity-name." .. PARENT }
pole.localised_description = { "entity-description." .. PARENT }
pole.minable = { mining_time = 1, result = PARENT }
pole.placeable_by = { item = PARENT, count = 1 }
pole.pictures = building
-- 1-direction picture -> one wire connection point; attach the copper wire at the top of the risen
-- mast so cables read as coming from the pole tip.
pole.connection_points = { { wire = { copper = { 0, -2.6 } }, shadow = { copper = { 0.7, -1.9 } } } }
pole.supply_area_distance = 20 -- engine +1/level -> 40x40 normal, exactly 50x50 at legendary
pole.maximum_wire_distance = 50 -- constant reach
pole.draw_copper_wires = true
pole.draw_circuit_wires = false
pole.circuit_wire_max_distance = 0
-- Take the roboport's footprint so the building sits right and the hidden roboport fits inside.
pole.collision_box = util.table.deepcopy(roboport_proto.collision_box)
pole.selection_box = util.table.deepcopy(roboport_proto.selection_box)
pole.next_upgrade = nil
pole.fast_replaceable_group = nil

-- Hidden roboport spawned under the pole (control.lua): provides the bots + draws the construction/
-- logistic radius. base blanked (pole draws the building); patch/antenna/doors still draw on top. --
local roboport = util.table.deepcopy(roboport_proto)
roboport.name = CHILD
roboport.icon = nil
roboport.icon_size = nil
roboport.icons = icons
roboport.localised_name = { "entity-name." .. PARENT }
roboport.localised_description = { "entity-description." .. PARENT }
roboport.hidden = true
roboport.selectable_in_game = false
roboport.base = blank -- the pole draws the building; avoid drawing it twice
roboport.draw_construction_radius_visualization = true
roboport.draw_logistic_radius_visualization = true
roboport.collision_mask = { layers = {} }
roboport.collision_box = util.table.deepcopy(roboport_proto.collision_box)
roboport.circuit_connector = nil
roboport.circuit_wire_max_distance = 0
roboport.minable = nil
roboport.next_upgrade = nil
roboport.fast_replaceable_group = nil
roboport.flags = {
  "placeable-off-grid",
  "not-blueprintable",
  "not-deconstructable",
  "not-upgradable",
  "not-in-kill-statistics",
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
-- TODO(M3): swap these placeholder ingredients for the Distrailia chain once it lands.
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
-- TODO(M3): re-point prerequisites/cost onto the Distrailia science pack + the rest of the branch.
local prerequisites = {}
local function add_prereq(name)
  if data.raw.technology[name] then table.insert(prerequisites, name) end
end
add_prereq("planet-discovery-distrailia")
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

data:extend({ pole, roboport, item, recipe, tech })
