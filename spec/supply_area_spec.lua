-- Unit tests for the superroboport supply-area curve (lib/supply_area.lua).
--
-- Written in the busted style (describe / it / assert.*) so the SAME file runs under:
--   * real busted          (CI / any machine with the Lua toolchain)
--   * tools/run_specs.lua  (local Windows runner: plain Lua + a tiny busted-compatible shim)
--
-- These encode the requirements we iterated on: floor 30x30 at normal, exactly 50x50 at
-- legendary, and EVEN spacing across the quality tiers (the "that's not linear" regression --
-- spacing must be by tier rank, not by raw quality level). All expected values are exact in
-- floating point, so assert.equals is safe (no tolerance needed).

local supply_area = require("lib.supply_area")

describe("supply_area.radius_for_rank", function()
  it("returns the cap for a single tier (avoids divide-by-zero)", function()
    assert.equals(25, supply_area.radius_for_rank(0, 1, 15, 25))
  end)

  it("returns floor at rank 0 and cap at the top rank", function()
    assert.equals(15, supply_area.radius_for_rank(0, 5, 15, 25))
    assert.equals(25, supply_area.radius_for_rank(4, 5, 15, 25))
  end)

  it("interpolates evenly between floor and cap", function()
    assert.equals(17.5, supply_area.radius_for_rank(1, 5, 15, 25))
    assert.equals(20.0, supply_area.radius_for_rank(2, 5, 15, 25))
    assert.equals(22.5, supply_area.radius_for_rank(3, 5, 15, 25))
  end)
end)

describe("supply_area.curve with the vanilla 5 quality tiers", function()
  local names = { "normal", "uncommon", "rare", "epic", "legendary" }
  local r = supply_area.curve(names, 15, 25)

  it("floors normal at radius 15 (30x30 tiles)", function()
    assert.equals(15, r.normal)
  end)

  it("caps legendary at exactly radius 25 (50x50 tiles)", function()
    assert.equals(25, r.legendary)
  end)

  it("produces the agreed per-tier radii", function()
    assert.equals(15, r.normal)
    assert.equals(17.5, r.uncommon)
    assert.equals(20, r.rare)
    assert.equals(22.5, r.epic)
    assert.equals(25, r.legendary)
  end)

  it("is linear across tiers: equal radius step between neighbours", function()
    local step = r.uncommon - r.normal
    assert.equals(step, r.rare - r.uncommon)
    assert.equals(step, r.epic - r.rare)
    -- The regression we fixed: legendary is quality level 5 (skips 4), so this last step must
    -- still equal the others because we space by tier RANK, not by raw level.
    assert.equals(step, r.legendary - r.epic)
  end)
end)

describe("supply_area.curve with 3 tiers", function()
  it("spaces evenly: floor, midpoint, cap", function()
    local r = supply_area.curve({ "a", "b", "c" }, 15, 25)
    assert.equals(15, r.a)
    assert.equals(20, r.b)
    assert.equals(25, r.c)
  end)
end)
