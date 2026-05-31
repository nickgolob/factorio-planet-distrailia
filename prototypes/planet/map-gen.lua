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
-- We keep the engine's DEFAULT elevation (continents + below-zero basins => lakes) and only
-- (a) force a dry climate so land resolves to desert, not grass, and (b) carve lava into some
-- basins. noise primitives (multioctave_noise, map_seed, x/y, elevation) are engine built-ins,
-- same ones the vanilla planets use.
data:extend({
  -- Driest possible: with no moisture, the listed red-desert tiles win on land (no grass tiles
  -- are listed, so nothing green can appear). 0 = driest. Overrides the moisture property.
  { type = "noise-expression", name = "distrailia_moisture", expression = "0" },

  -- Maximum "redness" so the red-desert tiles (aux-driven on Nauvis) blanket the land instead of
  -- leaving aux-dependent gaps. Overrides the aux property.
  { type = "noise-expression", name = "distrailia_aux", expression = "1" },

  -- Low-frequency blobs that decide which basins are lava vs water. > 0 => lava-eligible.
  {
    type = "noise-expression",
    name = "distrailia_lava_select",
    expression = "multioctave_noise{ x = x, y = y, seed0 = map_seed, seed1 = 1337,\z
                                     octaves = 3, persistence = 0.6, input_scale = 1 / 256, output_scale = 1 }",
  },

  -- Lava probability: positive ONLY in below-zero ground inside a lava blob, scaled by depth so
  -- it out-weighs water there (tile placement picks the highest-probability candidate). On land
  -- (elevation >= 0) -elevation is <= 0 so the term is negative => no lava. Magnitudes are a
  -- first-pass guess vs water's (unknown) scale -- tune live (DEV.md).
  {
    type = "noise-expression",
    name = "distrailia_lava_probability",
    expression = "(distrailia_lava_select > 0) * min(-elevation, 60) * 5 - 1",
  },

  -- lava-hot only in the deepest centres of the strongest blobs.
  {
    type = "noise-expression",
    name = "distrailia_lava_hot_probability",
    expression = "(distrailia_lava_select > 0.4) * min(-elevation - 8, 40) * 5 - 1",
  },
})

planet_map_gen.distrailia = function()
  return
  {
    property_expression_names =
    {
      moisture = "distrailia_moisture",
      aux = "distrailia_aux",
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
      -- No decoratives, trees, or enemies yet -- enemies are M2, bespoke flora/decoratives later.
    },
  }
end

return planet_map_gen
