-- Distrailia: "a hellscape of demons and rails".
--
-- Defines the planet and its position on the Space Age star map. This is an
-- intentionally minimal starting point: map generation, tiles, autoplace, and
-- art are stubbed with TODOs so the planet can be fleshed out incrementally.
--
-- Reference: https://lua-api.factorio.com/latest/prototypes/PlanetPrototype.html

local planet_map_gen = {
  -- TODO: replace with bespoke Distrailia terrain (lava/ash tiles, demon enemies,
  -- and rail-friendly traversal). Borrowed defaults keep the surface generatable
  -- until custom map gen lands.
  property_expression_names = {},
  autoplace_settings = {},
  cliff_settings = { name = "cliff", cliff_elevation_0 = 10, cliff_elevation_interval = 40 },
  default_enable_all_autoplace_controls = false,
}

data:extend({
  {
    type = "planet",
    name = "distrailia",
    -- TODO: add real art under graphics/. Placeholder paths are referenced so the
    -- intended asset layout is documented; supply these before enabling in-game.
    icon = "__distrailia__/graphics/icons/distrailia.png",
    icon_size = 64,
    starmap_icon = "__distrailia__/graphics/icons/distrailia-starmap.png",
    starmap_icon_size = 512,

    -- Star map placement. Tuned so Distrailia sits as its own destination; adjust
    -- distance/orientation to taste relative to the vanilla planets.
    distance = 38,
    orientation = 0.66,

    gravity_pull = 10,
    magnitude = 1.2,
    label_orientation = 0.62,

    draw_orbit = true,
    order = "z[distrailia]",

    map_gen_settings = planet_map_gen,

    surface_properties = {
      ["day-night-cycle"] = 7 * minute,
      ["magnetic-field"] = 90,
      ["solar-power"] = 50,
      ["pressure"] = 1000,
      ["gravity"] = 20,
    },

    pollutant_type = "pollution",

    -- TODO: define a procession set for arrival/departure cutscenes once art exists.
    -- planet_procession_set = { arrival = { "default-b" }, departure = { "default-rocket-a" } },
  },
})

-- Connection so the planet is reachable from the existing star map graph.
data:extend({
  {
    type = "space-connection",
    name = "nauvis-distrailia",
    subgroup = "planet-connections",
    from = "nauvis",
    to = "distrailia",
    order = "z",
    length = 16000,
    -- TODO: tune asteroid spawn definitions for the route.
    asteroid_spawn_definitions = {},
  },
})
