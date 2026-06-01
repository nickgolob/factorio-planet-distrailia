-- Distrailia runtime scripting.
--
-- Superroboport linking (SE Construction Pylon pattern). The placed entity is a POLE
-- ("superroboport", prototypes/entities/superroboport/superroboport.lua) wearing the roboport
-- building sprite; the hidden ROBOPORT half ("superroboport-roboport") is spawned under it here so
-- it provides the bots and draws the construction/logistic radius.
--
-- The pair lives and dies together:
--   * on every build path we create (or adopt) the hidden roboport under the pole;
--   * when the pole is removed by any means -- mined, died, deconstructed, scripted, surface
--     cleared -- register_on_object_destroyed fires and we destroy the roboport.
--
-- The roboport is spawned at the pole's quality, so its bot stats scale with quality; the pole's
-- own supply area is scaled by the engine's electric-pole bonus (40x40 normal -> 50x50 legendary).
--
-- register_on_object_destroyed -> on_object_destroyed reference:
--   https://lua-api.factorio.com/latest/classes/LuaBootstrap.html

local PARENT = "superroboport"         -- the placed pole (wears the roboport sprite)
local CHILD = "superroboport-roboport" -- the hidden roboport spawned underneath it

local function ensure_storage()
  storage.superroboport_roboports = storage.superroboport_roboports or {}
end

-- Create (or adopt an already-present) hidden roboport under a superroboport pole and tie its
-- lifetime to the pole. Idempotent: safe to call again for the same pole.
local function link(pole)
  if not (pole and pole.valid and pole.name == PARENT) then return end
  ensure_storage()
  local surface = pole.surface

  local roboport
  for _, e in pairs(surface.find_entities_filtered{ name = CHILD, position = pole.position, radius = 0.1 }) do
    if e.valid then
      roboport = e
      break
    end
  end
  if not (roboport and roboport.valid) then
    roboport = surface.create_entity{
      name = CHILD,
      position = pole.position,
      force = pole.force,
      quality = pole.quality, -- scales the roboport's bot stats with quality
    }
  end
  if not (roboport and roboport.valid) then return end
  roboport.destructible = false
  roboport.minable = false
  -- Registering the same entity twice returns the same number, so re-linking is harmless.
  local registration = script.register_on_object_destroyed(pole)
  storage.superroboport_roboports[registration] = roboport
end

local function on_build(event)
  link(event.entity)
end

local function on_clone(event)
  if event.destination and event.destination.valid and event.destination.name == PARENT then
    link(event.destination)
  end
end

local function on_destroyed(event)
  ensure_storage()
  local roboport = storage.superroboport_roboports[event.registration_number]
  if roboport then
    if roboport.valid then roboport.destroy() end
    storage.superroboport_roboports[event.registration_number] = nil
  end
end

-- Re-sync on init and on any mod/config change: ensure every existing superroboport pole has its
-- hidden roboport and is registered (e.g. when this mod is added to / updated in an existing save).
local function resync_all()
  ensure_storage()
  for _, surface in pairs(game.surfaces) do
    for _, pole in pairs(surface.find_entities_filtered{ name = PARENT }) do
      link(pole)
    end
  end
end

local build_filter = { { filter = "name", name = PARENT } }
script.on_event(defines.events.on_built_entity, on_build, build_filter)
script.on_event(defines.events.on_robot_built_entity, on_build, build_filter)
if defines.events.on_space_platform_built_entity then
  script.on_event(defines.events.on_space_platform_built_entity, on_build, build_filter)
end
-- script_raised_* and clone are left unfiltered (link() guards by name) to avoid relying on
-- per-event filter support.
script.on_event(defines.events.script_raised_built, on_build)
script.on_event(defines.events.script_raised_revive, on_build)
script.on_event(defines.events.on_entity_cloned, on_clone)
script.on_event(defines.events.on_object_destroyed, on_destroyed)

script.on_init(resync_all)
script.on_configuration_changed(resync_all)

-- Dev iteration helper -----------------------------------------------------------
-- Re-roll the Distrailia surface from its (freshly loaded) planet prototype, in the SAME save, and
-- chart the regenerated window so you can eyeball the layout. Map gen is data-stage, so after
-- editing prototypes/planet/map-gen.lua you must restart Factorio (data loads only at startup);
-- then /distrailia-regen pulls the new prototype settings onto the live surface -- no new save.
-- Optional arg = radius in chunks (default 12), e.g. /distrailia-regen 40.
-- reset_map_gen_settings: https://lua-api.factorio.com/latest/classes/LuaPlanet.html
commands.add_command("distrailia-regen",
  "Dev: re-roll Distrailia from its planet prototype and chart it. Optional radius in chunks (default 12), e.g. /distrailia-regen 40.",
  function(cmd)
    local planet = game.planets["distrailia"]
    if not planet then
      game.print("[distrailia] no 'distrailia' planet found.")
      return
    end
    local radius_chunks = tonumber(cmd.parameter) or 12
    planet.reset_map_gen_settings()
    local surface = planet.surface
    if not surface then
      game.print("[distrailia] Distrailia surface not generated yet -- travel there first.")
      return
    end
    -- Capture regen centres BEFORE clearing (clear wipes the surface, including characters).
    local centers = {}
    for _, player in pairs(game.connected_players) do
      if player.surface == surface then
        centers[#centers + 1] = { player = player, position = player.position }
      end
    end
    surface.clear(true)
    if #centers == 0 then centers = { { position = { x = 0, y = 0 } } } end
    -- request_to_generate_chunks radius is in CHUNKS; chart bounds are in TILES (32 tiles/chunk).
    local tiles = radius_chunks * 32
    for _, c in pairs(centers) do
      surface.request_to_generate_chunks(c.position, radius_chunks)
    end
    surface.force_generate_chunk_requests()
    for _, c in pairs(centers) do
      local px, py = c.position.x, c.position.y
      local force = (c.player and c.player.valid) and c.player.force or game.forces.player
      if force then
        force.chart(surface, { { px - tiles, py - tiles }, { px + tiles, py + tiles } })
      end
      if c.player and c.player.valid then
        c.player.teleport(c.position, surface)
      end
    end
    game.print("[distrailia] regenerated + charted radius " .. radius_chunks .. " chunks (" .. tiles .. " tiles).")
  end)

-- Dev iteration helper: capture the BUILD-CURSOR preview -------------------------------------------
-- The build-cursor preview (item-in-hand sprite + supply area + cable-connection lines) renders at
-- your live MOUSE position, so it can only be screenshotted from a real client -- the automated
-- off-screen runner has no mouse over the world and can't (Windows clamps a scripted cursor to the
-- visible desktop). This captures it from YOUR game instead: run it, close the console, hold the
-- superroboport and aim where you want it; ~3s later it writes script-output/distrailia/cursor.png
-- via take_screenshot{ show_cursor_building_preview = true }.
commands.add_command("distrailia-cursor-shot",
  "Dev: in ~3s, screenshot the build-cursor preview of the item you're holding -> script-output/distrailia/cursor.png. Hold the superroboport and aim before it fires.",
  function(cmd)
    if not cmd.player_index then return end
    storage.cursor_shot = { player = cmd.player_index, at = game.tick + 180 }
    local player = game.get_player(cmd.player_index)
    if player then
      player.print("[distrailia] capturing the build-cursor preview in 3s -- close the console, hold the superroboport, and aim.")
    end
  end)

-- Fires the pending cursor-shot once its delay elapses (cheap: returns immediately when none pending).
script.on_nth_tick(15, function()
  local c = storage.cursor_shot
  if not (c and game.tick >= c.at) then return end
  storage.cursor_shot = nil
  local player = game.get_player(c.player)
  if not (player and player.valid) then return end
  game.take_screenshot{
    player = player,
    show_cursor_building_preview = true,
    show_gui = false,
    resolution = { 1024, 1024 },
    zoom = 1.5,
    path = "distrailia/cursor.png",
    anti_alias = true,
    force_render = true,
  }
  player.print("[distrailia] wrote script-output/distrailia/cursor.png")
end)

-- In-game integration tests, loaded only when the factorio-test mod is active (a `?` optional
-- dependency, so normal play never loads it). See the superroboport folder + TESTING.md.
-- The visual suite (screenshot_test) is also a FactorioTest "test"; capture real images with the
-- off-screen runner visual_tests/run.ps1 (npx factorio-test run -g "screenshot").
if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "prototypes.entities.superroboport.superroboport_test",
    "prototypes.entities.superroboport.screenshot_test",
  })
end
