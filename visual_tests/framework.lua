-- Visual-test framework (generic infrastructure) -------------------------------------------------
--
-- Minimal, reusable helpers for Factorio "visual tests": lay a clean patch of ground, build an
-- entity, and write a framed screenshot to <write-data>/script-output/. The screenshots capture ONLY
-- what the engine itself renders -- no drawn annotations. To show overlays the game only draws on
-- hover/cursor (supply area, robot areas, build preview), drive a player to select the entity or
-- hold the item; the engine then renders them for real and take_screenshot captures that.
--
-- Rendering only produces real images with a render thread (GRAPHICS mode). The off-screen runner is
-- visual_tests/run.ps1; the headless factorio-test runner has none, so under CI the scenes build but
-- no PNG is written.

local F = {}

F.RES = 768 -- screenshots are RES x RES px; at zoom 1, 1 tile = 32 px (kept modest so goldens stay small)

-- Pick a zoom so `tiles` world-tiles fill the RES-px image (clamped to sane bounds).
function F.zoom_for(tiles)
  local z = F.RES / (32 * math.max(tiles, 1))
  if z < 0.2 then return 0.2 elseif z > 3 then return 3 end
  return z
end

-- Clean square patch: paving + remove non-character entities, full daylight for consistent shots.
function F.prep_ground(surface, center, r, tile)
  surface.always_day = true
  tile = tile or "refined-concrete"
  local tiles = {}
  for dx = -r, r do
    for dy = -r, r do
      tiles[#tiles + 1] = { name = tile, position = { center.x + dx, center.y + dy } }
    end
  end
  surface.set_tiles(tiles)
  for _, e in pairs(surface.find_entities_filtered{ area = { { center.x - r, center.y - r }, { center.x + r, center.y + r } } }) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

function F.build(surface, name, pos, quality)
  return surface.create_entity{ name = name, position = pos, force = "player", quality = quality, raise_built = true }
end

-- Write one screenshot framed so `tiles` world-tiles are visible, to script-output/<path>.png.
-- `player` (optional): render from that player's perspective. `cursor_preview` (optional): when a
-- player is given, render the engine's REAL build-cursor preview for the item in that player's
-- cursor (sprite + supply area + copper-cable connection lines).
function F.shot(path, surface, pos, tiles, show_entity_info, player, cursor_preview)
  game.take_screenshot{
    player = player,
    surface = surface,
    position = pos,
    resolution = { F.RES, F.RES },
    zoom = F.zoom_for(tiles),
    path = path .. ".png",
    show_entity_info = show_entity_info or false,
    show_cursor_building_preview = cursor_preview or false,
    anti_alias = true,
    force_render = true, -- don't drop the frame; ensures the (cursor) render is processed
  }
end

return F
