-- Pure supply-area curve math for the superroboport's hidden substation.
--
-- Deliberately free of any Factorio globals (no `data`, `util`, `game`, ...), so it can be
-- unit-tested with plain Lua / busted -- see supply_area_spec.lua. The data stage
-- (prototypes/entities/superroboport/superroboport.lua) reads the quality tiers from data.raw and
-- asks this module only for the arithmetic. Keep this file Lua 5.2-compatible (Factorio's VM).

local supply_area = {}

-- Radius for the tier at sorted rank `index` (0 = lowest/normal) out of `count` tiers,
-- interpolated linearly from `floor` (rank 0) to `cap` (top rank). Spacing is even across
-- tiers regardless of the qualities' raw `level` values (legendary is level 5, skipping 4,
-- so interpolating by level would leave an uneven jump at the top).
function supply_area.radius_for_rank(index, count, floor, cap)
  if count <= 1 then
    return cap
  end
  return floor + (cap - floor) * (index / (count - 1))
end

-- Given quality tier names already sorted low -> high, return a map of name -> radius,
-- evenly spaced from `floor` (first) to `cap` (last).
function supply_area.curve(sorted_names, floor, cap)
  local out = {}
  local count = #sorted_names
  for i = 1, count do
    out[sorted_names[i]] = supply_area.radius_for_rank(i - 1, count, floor, cap)
  end
  return out
end

return supply_area
