-- In-game integration tests for the superroboport (run via FactorioTest -- see TESTING.md).
--
-- Architecture under test (superroboport.md, SE Construction Pylon pattern): the PLACED entity is
-- the power POLE "superroboport" (type electric-pole); a hidden roboport "superroboport-roboport"
-- is spawned under it by control.lua at the pole's quality.
--
-- Covered (API-observable) requirements:
--   * building the pole spawns the paired hidden roboport;
--   * the pole's supply area is 40x40 at normal and 50x50 at legendary (per quality);
--   * wire/connection reach is a constant 50;
--   * the roboport is actually powered by a generator placed in the supply area;
--   * removing the pole removes the roboport (no orphan).
--
-- NOT covered (no API exposes it): the VISUAL build-cursor previews -- the radius squares, network
-- lines, and copper-cable lines shown while holding the item. Those stay manual checks.
--
-- Assertions use plain Lua `assert(cond, message)` (FactorioTest 3.x does NOT provide luassert).

local PARENT = "superroboport"         -- the placed pole
local CHILD = "superroboport-roboport" -- the hidden roboport spawned underneath

local function build_superroboport(surface, pos, quality)
  local tiles = {}
  for dx = -4, 4 do
    for dy = -4, 4 do
      tiles[#tiles + 1] = { name = "grass-1", position = { pos.x + dx, pos.y + dy } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered{ area = { { pos.x - 4, pos.y - 4 }, { pos.x + 4, pos.y + 4 } } }) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  return surface.create_entity{
    name = PARENT,
    position = pos,
    force = "player",
    quality = quality,
    raise_built = true,
  }
end

local function find_roboport(surface, pos)
  for _, e in pairs(surface.find_entities_filtered{ name = CHILD, position = pos, radius = 0.6 }) do
    if e.valid then return e end
  end
  return nil
end

test("building a superroboport places a pole and spawns a hidden roboport under it", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 24 }
  local pole = build_superroboport(surface, pos, "normal")
  assert(pole and pole.valid, "superroboport (pole) was not created")
  assert(pole.type == "electric-pole", "placed entity should be an electric-pole, was " .. pole.type)

  local roboport = find_roboport(surface, pos)
  assert(roboport, "expected a hidden roboport under the superroboport")
  assert(roboport.type == "roboport", "spawned entity should be a roboport, was " .. tostring(roboport.type))
  assert(roboport.destructible == false, "hidden roboport should be indestructible")
end)

test("power area scales with quality: 40x40 (normal) and 50x50 (legendary)", function()
  local surface = game.surfaces[1]

  local pole_n = build_superroboport(surface, { x = 0, y = 48 }, "normal")
  assert(pole_n and pole_n.valid, "normal: pole not created")
  assert(pole_n.quality.name == "normal", "pole should be normal quality, was " .. pole_n.quality.name)
  assert(pole_n.prototype.get_supply_area_distance(pole_n.quality.name) == 20,
    "normal supply radius should be 20 (40x40), was " .. tostring(pole_n.prototype.get_supply_area_distance(pole_n.quality.name)))

  local pole_l = build_superroboport(surface, { x = 16, y = 48 }, "legendary")
  assert(pole_l and pole_l.valid, "legendary: pole not created")
  assert(pole_l.quality.name == "legendary", "pole should be legendary quality, was " .. pole_l.quality.name)
  assert(pole_l.prototype.get_supply_area_distance(pole_l.quality.name) == 25,
    "legendary supply radius should be 25 (50x50), was " .. tostring(pole_l.prototype.get_supply_area_distance(pole_l.quality.name)))

  pole_n.destroy()
  pole_l.destroy()
end)

test("wire/connection reach is a constant 50", function()
  local reach = prototypes.entity[PARENT].get_max_wire_distance("normal")
  assert(reach == 50, "wire reach should be a constant 50, was " .. tostring(reach))
end)

test("the superroboport is powered by a generator inside its supply area", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 72 }
  local pole = build_superroboport(surface, pos, "normal")
  assert(pole and pole.valid, "superroboport pole was not created")
  local roboport = find_roboport(surface, pos)
  assert(roboport, "expected a hidden roboport")

  local source = surface.create_entity{ name = "electric-energy-interface", position = { pos.x + 3, pos.y }, force = "player" }
  assert(source and source.valid, "could not place a test power source")
  source.power_production = 10000000 -- W; far exceeds the roboport's draw
  source.energy = source.electric_buffer_size

  async()
  after_ticks(10, function()
    assert(roboport.valid, "roboport vanished")
    assert(roboport.electric_network_id ~= nil, "roboport is not on an electric network")
    assert(roboport.energy > 0, "roboport is not drawing power (energy=" .. tostring(roboport.energy) .. ")")
    pole.destroy()
    if source.valid then source.destroy() end
    done()
  end)
end)

test("removing the superroboport destroys its hidden roboport (no orphan)", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 96 }
  local pole = build_superroboport(surface, pos, "normal")
  assert(find_roboport(surface, pos), "expected a hidden roboport right after build")

  pole.destroy()
  async()
  after_ticks(3, function() -- on_object_destroyed fires at the end of the current/next tick
    assert(find_roboport(surface, pos) == nil, "hidden roboport was not cleaned up after the pole was removed")
    done()
  end)
end)
