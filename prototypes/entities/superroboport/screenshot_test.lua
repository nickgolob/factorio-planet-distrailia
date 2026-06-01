-- Superroboport visual tests (FactorioTest). Two tests, each writing PNGs to script-output/distrailia/.
-- Golden references live in superroboport/golden/. Rendering needs a graphics render thread (the
-- headless --benchmark runner has none, so these build but write nothing under plain CI).
--
--   * "screenshot ..."  -- sprite + network; captured off-screen by visual_tests/run.ps1.
--   * "cursor ..."      -- the REAL build-cursor preview. It only renders at a real mouse over an
--                          on-screen client, so visual_tests/run.ps1 -Cursor briefly brings the
--                          instance on-screen and holds the mouse while this shoots repeatedly
--                          (whichever frames coincide with the positioned mouse capture the preview).

local visual = require("prototypes.entities.superroboport.visual")

test("screenshot: superroboport visual scenes (sprite, network)", function()
  local count, first = visual.capture(game.surfaces[1])
  assert(first and first.valid, "visual test: superroboport scene did not build")
  assert(count == 2, "expected 2 scenes, got " .. tostring(count))
  async()
  after_ticks(120, function() done() end)
end)

test("cursor: superroboport build-cursor preview", function()
  local surface = game.surfaces[1]
  local player, c = visual.cursor_setup(surface)
  -- Signal the runner the game is loaded + about to shoot, so it brings the window on-screen now.
  pcall(function() helpers.write_file("distrailia/cursor-ready.txt", "ready", false) end)
  if player then
    player.print("[distrailia] MOVE YOUR MOUSE over this window and HOLD it where you'd place the")
    player.print("[distrailia] superroboport (near the structure on the left). Capturing ~10 frames...")
  end
  async()
  -- Take several numbered frames; you hold your real mouse over the world during this window and the
  -- engine renders the preview at it. The runner keeps the window on-screen + focused meanwhile.
  local n = 0
  local function tick_shot()
    n = n + 1
    visual.cursor_shot(surface, player, c, n)
    if player then player.print("[distrailia] frame " .. n .. "/10 -- keep aiming...") end
    if n < 10 then after_ticks(36, tick_shot) else done() end
  end
  after_ticks(150, tick_shot) -- ~2.5s for the window to come on-screen and you to position the mouse
end)
