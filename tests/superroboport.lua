-- In-game integration tests for the superroboport (run via FactorioTest -- see TESTING.md).
--
-- These exercise what the pure unit tests (spec/) and luacheck CANNOT: the actual data stage
-- loading and the control.lua lifecycle in a live game. They run only under the test runner
-- (control.lua loads factorio-test as a `?` optional dependency).
--
-- What we assert (the real integration concerns):
--   * building a superroboport spawns the per-quality hidden substation variant underneath it;
--   * that substation is spawned at NORMAL quality, so its supply area is exactly the intended
--     size (spawning at the roboport's quality would let the engine inflate it past 50x50);
--   * the resulting in-game supply area is 30x30 at normal and 50x50 at legendary;
--   * removing the roboport (which fires on_object_destroyed at end of tick) destroys the
--     substation with it -- no orphaned, invisible power coverage left behind.
--
-- Assertions use plain Lua `assert(cond, message)` (FactorioTest 3.x does NOT replace the global
-- `assert` with luassert); a failing assert throws and the runner records the test as failed.

local CHILD_PREFIX = "superroboport-substation-"

-- Build a superroboport at `pos` on `surface` at the given quality, on guaranteed-clear ground.
local function build_superroboport(surface, pos, quality)
  local tiles = {}
  for dx = -3, 3 do
    for dy = -3, 3 do
      tiles[#tiles + 1] = { name = "grass-1", position = { pos.x + dx, pos.y + dy } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered{ area = { { pos.x - 3, pos.y - 3 }, { pos.x + 3, pos.y + 3 } } }) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  return surface.create_entity{
    name = "superroboport",
    position = pos,
    force = "player",
    quality = quality,
    raise_built = true, -- fires script_raised_built -> control.lua creates the hidden substation
  }
end

local function find_substation(surface, pos)
  for _, e in pairs(surface.find_entities_filtered{ position = pos, radius = 0.6 }) do
    if e.valid and e.name:sub(1, #CHILD_PREFIX) == CHILD_PREFIX then
      return e
    end
  end
  return nil
end

local function count_substations(surface, pos)
  local n = 0
  for _, e in pairs(surface.find_entities_filtered{ position = pos, radius = 0.6 }) do
    if e.valid and e.name:sub(1, #CHILD_PREFIX) == CHILD_PREFIX then
      n = n + 1
    end
  end
  return n
end

test("a normal superroboport spawns a 30x30 hidden substation", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 24 }
  local roboport = build_superroboport(surface, pos, "normal")
  assert(roboport and roboport.valid, "superroboport was not created")

  local sub = find_substation(surface, pos)
  assert(sub, "expected a hidden substation under the superroboport")
  assert(sub.name == "superroboport-substation-normal", "wrong variant: " .. sub.name)
  assert(sub.type == "electric-pole", "wrong type: " .. sub.type)
  assert(sub.destructible == false, "substation should be indestructible")
  -- Spawned at normal quality => no quality bonus => supply area is exactly the base value.
  assert(sub.quality.name == "normal", "substation should be normal quality, was " .. sub.quality.name)
  assert(sub.prototype.get_supply_area_distance(sub.quality.name) == 15,
    "supply area should be 15 (30x30), was " .. tostring(sub.prototype.get_supply_area_distance(sub.quality.name)))

  roboport.destroy()
end)

test("a legendary superroboport spawns a 50x50 substation (still at normal quality)", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 48 }
  local roboport = build_superroboport(surface, pos, "legendary")
  assert(roboport and roboport.valid, "legendary superroboport was not created")
  assert(roboport.quality.name == "legendary", "roboport should be legendary, was " .. roboport.quality.name)

  local sub = find_substation(surface, pos)
  assert(sub, "expected a hidden substation under the legendary superroboport")
  assert(sub.name == "superroboport-substation-legendary", "wrong variant: " .. sub.name)
  -- The key invariant: the substation is normal quality, so the 50x50 isn't inflated by the
  -- engine's per-quality supply-area bonus.
  assert(sub.quality.name == "normal", "substation should be normal quality, was " .. sub.quality.name)
  assert(sub.prototype.get_supply_area_distance(sub.quality.name) == 25,
    "supply area should be 25 (50x50), was " .. tostring(sub.prototype.get_supply_area_distance(sub.quality.name)))

  roboport.destroy()
end)

test("removing a superroboport destroys its hidden substation", function()
  local surface = game.surfaces[1]
  local pos = { x = 0, y = 72 }
  local roboport = build_superroboport(surface, pos, "normal")
  assert(roboport and roboport.valid, "superroboport was not created")
  assert(count_substations(surface, pos) == 1, "expected exactly 1 substation right after build")

  roboport.destroy()
  -- Cleanup runs from on_object_destroyed, which fires at the end of the current/next tick,
  -- so wait a couple ticks before asserting the substation is gone.
  async()
  after_ticks(3, function()
    assert(count_substations(surface, pos) == 0, "substation was not cleaned up after the roboport was removed")
    done()
  end)
end)
