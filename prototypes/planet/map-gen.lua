-- Distrailia map generation -- authored from scratch (no Nauvis copy).
--
-- Follows the majority pattern of the pack's other planet mods: build on Wube's planet-map-gen
-- helper and list our own tiles / autoplace controls, rather than deep-copying a vanilla planet.
-- Pattern reference: __space-age__/prototypes/planet/planet-map-gen.lua (.vulcanus/.fulgora add a
-- function to the shared table returned by __base__/prototypes/planet/planet-map-gen.lua).
--
-- Milestone scope (DESIGN.md / TODO.md): vanilla red-desert land, a MIX of water and lava lakes
-- in the low ground, and all Nauvis ores. Bespoke tiles, the demonite/hellstone/souls resources
-- (M3), enemies (M2), and chasms (own task) are intentionally NOT here yet.
--
-- UNVERIFIED IN-GAME: the dry-desert climate and the lava/water lake split are hand-authored
-- noise that has not been tuned against a running map. Worst case is "too much / too little lava"
-- or uniform desert -- not a crash. Expect to dial the magnitudes live -- see DEV.md.

local planet_map_gen = require("__base__/prototypes/planet/planet-map-gen")

-- Hand-authored noise -----------------------------------------------------------
-- Engine DEFAULT elevation (continents + below-zero basins => lakes). We (a) force a dry climate
-- so land resolves to desert not grass, and (b) explicitly drive the liquid tiles so WATER and
-- LAVA partition the basins: water is forced negative where lava goes, which is the ONLY way lava
-- reliably appears (otherwise water's probability out-competes it -- that was the "no lava" bug).
-- Per-tile probability overrides are the documented mechanism:
-- https://lua-api.factorio.com/latest/concepts/MapGenSettings.html

-- KNOBS -- tweak these, then /distrailia-regen (see DEV.md):
local LIQUID_DEPTH = 2     -- lakes only where elevation < -LIQUID_DEPTH; raise => smaller lakes / less water
local LAVA_SHARE   = -0.2  -- basins with lava_select > this become LAVA, else water; lower => MORE lava, less water
local LAVA_HOT     = 0.4   -- stronger lava blobs get a lava-hot centre
local DEEP_EXTRA   = 8     -- deepwater / lava-hot begin this much below the shoreline

data:extend({
  -- Driest possible: with no moisture the listed red-desert tiles win on land. 0 = driest.
  { type = "noise-expression", name = "distrailia_moisture", expression = "0" },

  -- Maximum "redness" so red-desert (aux-driven on Nauvis) blankets the land.
  { type = "noise-expression", name = "distrailia_aux", expression = "1" },

  -- Low-frequency blobs splitting lakes: lava where > LAVA_SHARE, water where < LAVA_SHARE.
  {
    type = "noise-expression",
    name = "distrailia_lava_select",
    expression = "multioctave_noise{ x = x, y = y, seed0 = map_seed, seed1 = 1337,\z
                                     octaves = 3, persistence = 0.6, input_scale = 1 / 256, output_scale = 1 }",
  },

  -- Per-tile probabilities: positive only in the tile's basin region below the shoreline depth,
  -- negative elsewhere (so desert wins on land). Water is negative in lava regions => lava appears.
  {
    type = "noise-expression",
    name = "distrailia_water_probability",
    expression = "(distrailia_lava_select < " .. LAVA_SHARE .. ") * (-elevation - " .. LIQUID_DEPTH .. ")",
  },
  {
    type = "noise-expression",
    name = "distrailia_deepwater_probability",
    expression = "(distrailia_lava_select < " .. LAVA_SHARE .. ") * (-elevation - " .. (LIQUID_DEPTH + DEEP_EXTRA) .. ")",
  },
  {
    type = "noise-expression",
    name = "distrailia_lava_probability",
    expression = "(distrailia_lava_select > " .. LAVA_SHARE .. ") * (-elevation - " .. LIQUID_DEPTH .. ")",
  },
  {
    type = "noise-expression",
    name = "distrailia_lava_hot_probability",
    expression = "(distrailia_lava_select > " .. LAVA_HOT .. ") * (-elevation - " .. (LIQUID_DEPTH + DEEP_EXTRA) .. ")",
  },
})

planet_map_gen.distrailia = function()
  return
  {
    -- Whitelist-only generation. This flag plus treat_missing_as_default=false on each
    -- autoplace_settings type (below) mean ONLY the tiles/entities/controls we list are placed.
    -- This is what keeps TREES (and Nauvis rocks/decoratives) off: trees are entities we don't
    -- list, and the engine DEFAULTS unlisted things to enabled, so omitting them is NOT enough.
    -- Source: https://lua-api.factorio.com/latest/types/AutoplaceSettings.html
    default_enable_all_autoplace_controls = false,
    property_expression_names =
    {
      moisture = "distrailia_moisture",
      aux = "distrailia_aux",
      ["tile:water:probability"] = "distrailia_water_probability",
      ["tile:deepwater:probability"] = "distrailia_deepwater_probability",
      ["tile:lava:probability"] = "distrailia_lava_probability",
      ["tile:lava-hot:probability"] = "distrailia_lava_hot_probability",
    },
    autoplace_controls =
    {
      -- All Nauvis ores. Frequency/size/richness (rail-world spacing) are applied in
      -- prototypes/planet.lua, which is the single source of truth for those values.
      ["iron-ore"] = {},
      ["copper-ore"] = {},
      ["stone"] = {},
      ["coal"] = {},
      ["uranium-ore"] = {},
      ["crude-oil"] = {},
      ["water"] = {}, -- enables the water lakes
    },
    autoplace_settings =
    {
      ["tile"] =
      {
        treat_missing_as_default = false, -- only the tiles listed here generate
        settings =
        {
          -- Vanilla "desert" set (Nauvis has no desert-N tile; the desert family is red-desert/sand).
          ["red-desert-0"] = {},
          ["red-desert-1"] = {},
          ["red-desert-2"] = {},
          ["red-desert-3"] = {},
          -- Lakes: water + lava, mixed by distrailia_lava_select above.
          ["water"] = {},
          ["deepwater"] = {},
          ["lava"] = {},      -- __space-age__/prototypes/tile/tiles-vulcanus.lua
          ["lava-hot"] = {},
        },
      },
      ["entity"] =
      {
        treat_missing_as_default = false, -- ONLY these ores spawn; trees/rocks/fish are unlisted -> never placed
        settings =
        {
          ["iron-ore"] = {},
          ["copper-ore"] = {},
          ["stone"] = {},
          ["coal"] = {},
          ["uranium-ore"] = {},
          ["crude-oil"] = {},
        },
      },
      -- Bare ground: empty list + treat_missing_as_default=false strips Nauvis rocks/grass decals.
      -- (Enemies are M2; bespoke flora/decoratives come later.)
      ["decorative"] =
      {
        treat_missing_as_default = false,
        settings = {},
      },
    },
  }
end

return planet_map_gen
