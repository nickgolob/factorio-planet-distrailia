-- Distrailia data-final-fixes.
--
-- Per-quality hidden-substation variants for the superroboport.
--
-- This MUST run here, not in the data stage. Quality prototypes (data.raw.quality) are not yet
-- populated while prototypes/entities/superroboport.lua runs, so iterating them there produces no
-- variants -- the symptom being control.lua reporting the substation prototype missing and the
-- superroboport supplying no power. By data-final-fixes every mod's qualities are defined, so we
-- deep-copy the base template (defined in the data stage) once per tier with an evenly-spaced
-- supply area (30x30 floor -> 50x50 at the top) and wire reach (30 -> 50 tiles at the top), so the
-- connection range matches the supply-area width at every quality.
--
-- The arithmetic lives in lib/supply_area.lua (unit-tested in spec/supply_area_spec.lua).

local util = require("util")
local supply_area = require("lib.supply_area")

local CHILD = "superroboport-substation"
local FLOOR_RADIUS = 15 -- supply area: lowest tier -> 30x30
local CAP_RADIUS = 25   -- supply area: top tier   -> 50x50
local FLOOR_WIRE = 30   -- wire reach: lowest tier -> 30 tiles
local CAP_WIRE = 50     -- wire reach: top tier    -> 50 tiles (legendary)

local template = data.raw["electric-pole"][CHILD]
if not template then
  error("[distrailia] hidden-substation template '" .. CHILD .. "' is missing; "
    .. "prototypes/entities/superroboport.lua must define it in the data stage.")
end

-- Non-hidden qualities, sorted low -> high; the supply area is spaced evenly across the tiers.
local qualities = {}
for _, q in pairs(data.raw.quality or {}) do
  if not q.hidden then qualities[#qualities + 1] = q end
end
table.sort(qualities, function(a, b) return (a.level or 0) < (b.level or 0) end)

local sorted_names = {}
for i, q in ipairs(qualities) do sorted_names[i] = q.name end
local radius_by_quality = supply_area.curve(sorted_names, FLOOR_RADIUS, CAP_RADIUS)
local wire_by_quality = supply_area.curve(sorted_names, FLOOR_WIRE, CAP_WIRE)

local variants = {}
local has_normal = false
for _, q in ipairs(qualities) do
  local variant = util.table.deepcopy(template)
  variant.name = CHILD .. "-" .. q.name
  variant.supply_area_distance = radius_by_quality[q.name]
  variant.maximum_wire_distance = wire_by_quality[q.name]
  variants[#variants + 1] = variant
  if q.name == "normal" then has_normal = true end
end

-- Safety net: control.lua falls back to the "-normal" variant, so guarantee it exists even if no
-- quality prototypes were found (no quality system -> no scaling, so grant the full area).
if not has_normal then
  local normal = util.table.deepcopy(template)
  normal.name = CHILD .. "-normal"
  normal.supply_area_distance = CAP_RADIUS
  normal.maximum_wire_distance = CAP_WIRE
  variants[#variants + 1] = normal
end

data:extend(variants)
