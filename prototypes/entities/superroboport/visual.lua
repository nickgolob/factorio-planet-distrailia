-- Superroboport visual scenes (feature-specific test logic) --------------------------------------
--
-- Captures ONLY what the engine itself renders -- no drawn annotations:
--   * M.capture  -> 01-sprite (placed) and 02-network (real auto-connected copper cables).
--   * M.cursor_* -> the REAL build-cursor preview (sprite + supply area + cable lines), via
--                   take_screenshot{ show_cursor_building_preview = true }. That preview only renders
--                   at a real MOUSE over an on-screen client, so visual_tests/run.ps1 -Cursor briefly
--                   brings the instance on-screen and positions the mouse while this shoots.
--
-- Output: <write-data>/script-output/distrailia/*.png. Golden references live in superroboport/golden/.

local F = require("visual_tests.framework")

local PARENT = "superroboport"

local function any_player()
  for _, p in pairs(game.players) do if p.valid then return p end end
  return nil
end

local M = {}

function M.capture(surface)
  local dir = "distrailia/"

  -- 1) Sprite -- the placed superroboport (merged roboport base + power-pole mast), closeup.
  local c1 = { x = 0, y = -80 }
  F.prep_ground(surface, c1, 18)
  local first = F.build(surface, PARENT, c1, "normal")

  -- 2) Network -- a row of superroboports + a substation, showing the REAL copper cables the engine
  --    auto-connects (at the mast tops) and that it wires into the vanilla grid.
  local c2 = { x = 7, y = -200 }
  F.prep_ground(surface, c2, 50)
  F.build(surface, PARENT, { x = -20, y = c2.y }, "normal")
  F.build(surface, PARENT, { x = 0, y = c2.y }, "normal")
  F.build(surface, PARENT, { x = 20, y = c2.y }, "normal")
  surface.create_entity{ name = "substation", position = { x = 34, y = c2.y }, force = "player" }
  local src = surface.create_entity{ name = "electric-energy-interface", position = { x = -20, y = c2.y - 6 }, force = "player" }
  if src and src.valid then
    src.power_production = 5000000
    src.energy = src.electric_buffer_size
  end

  F.shot(dir .. "01-sprite", surface, c1, 16, false)
  F.shot(dir .. "02-network", surface, c2, 74, true)
  return 2, first
end

-- Cursor preview: place a neighbour (so the preview draws a cable line), put the superroboport in the
-- player's cursor, and stand the player there. The actual screenshot is taken (repeatedly) by
-- M.cursor_shot while run.ps1 -Cursor holds the OS mouse over the on-screen window.
function M.cursor_setup(surface)
  local c = { x = 0, y = 120 }
  F.prep_ground(surface, c, 28)
  F.build(surface, PARENT, { x = c.x - 10, y = c.y }, "normal") -- neighbour for the cable-connection line
  local player = any_player()
  if player then
    player.teleport(c, surface)
    pcall(function() player.cursor_stack.set_stack{ name = PARENT } end)
  end
  return player, c
end

-- One numbered frame; the preview renders wherever the real mouse is, so the player aims it. We frame
-- generously around the build spot and take several, so the developer can pick the best.
function M.cursor_shot(surface, player, c, idx)
  F.shot(string.format("distrailia/cursor-%02d", idx), surface, (player and player.position) or c, 40, false, player, true)
end

return M
