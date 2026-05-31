-- Distrailia runtime scripting.
--
-- Superroboport linking. The superroboport (prototypes/entities/superroboport.lua) is a
-- roboport prototype; its power area comes from a hidden substation spawned underneath it here.
-- The pair must live and die together:
--   * on every build path we create (or adopt) the hidden substation under the roboport;
--   * when the roboport is removed by any means -- mined, died, deconstructed, scripted,
--     surface cleared -- register_on_object_destroyed fires and we destroy the substation.
--
-- The supply area scales with the roboport's quality (30x30 at normal up to 50x50 at legendary).
-- There is one hidden-pole variant per quality ("<CHILD_PREFIX><quality>"), each with the right
-- supply_area_distance baked in; we spawn the matching variant at NORMAL quality so the engine
-- adds no further bonus. If a stale substation is the wrong variant, we rebuild it.
--
-- register_on_object_destroyed -> on_object_destroyed reference:
--   https://lua-api.factorio.com/latest/classes/LuaBootstrap.html

local PARENT = "superroboport"
local CHILD_PREFIX = "superroboport-substation-" -- per-quality variants: <prefix>normal .. <prefix>legendary

local function ensure_storage()
  storage.superroboport_children = storage.superroboport_children or {}
end

-- Create (or adopt an already-present) hidden substation under a superroboport and tie its
-- lifetime to the roboport. Idempotent: safe to call again for the same roboport.
local function link(roboport)
  if not (roboport and roboport.valid and roboport.name == PARENT) then return end
  ensure_storage()
  local surface = roboport.surface
  -- The per-quality variant this roboport should have under it (fall back to normal for any
  -- quality without a variant, e.g. an exotic modded one).
  local want = CHILD_PREFIX .. roboport.quality.name
  if not prototypes.entity[want] then want = CHILD_PREFIX .. "normal" end
  -- Even the normal fallback can be missing if the data stage and this script disagree (a
  -- half-applied mod update, or another mod stripping the variant). create_entity on an unknown
  -- name is a non-recoverable error, and link() runs from on_configuration_changed -- so an
  -- unguarded call would crash on load and brick the save. Surface it loudly (log + in-game) and
  -- skip rather than crash.
  if not prototypes.entity[want] then
    local message = "[distrailia] missing hidden-substation prototype '" .. want
      .. "'; this superroboport will supply no power. Reload/reinstall the mod cleanly."
    log(message)
    game.print(message)
    return
  end

  -- Find any of our substation variants already under the roboport.
  local substation
  for _, e in pairs(surface.find_entities_filtered{ position = roboport.position, radius = 0.1 }) do
    if e.valid and e.name:sub(1, #CHILD_PREFIX) == CHILD_PREFIX then
      substation = e
      break
    end
  end
  -- Rebuild if it is the wrong variant (e.g. the roboport's quality changed via migration).
  if substation and substation.valid and substation.name ~= want then
    substation.destroy()
    substation = nil
  end
  if not (substation and substation.valid) then
    -- Spawn at default (normal) quality so the engine adds no supply-area bonus on top of the
    -- per-quality value baked into the variant prototype.
    substation = surface.create_entity{ name = want, position = roboport.position, force = roboport.force }
  end
  if not (substation and substation.valid) then return end
  substation.destructible = false
  substation.minable = false
  -- Registering the same entity twice returns the same number, so re-linking is harmless.
  local registration = script.register_on_object_destroyed(roboport)
  storage.superroboport_children[registration] = substation
end

local function on_build(event)
  link(event.entity)
end

local function on_clone(event)
  -- A cloned roboport may have brought its substation along; link() adopts it if so,
  -- otherwise it creates a fresh one. (An orphaned cloned substation, if any, is harmless:
  -- it is indestructible / not minable and will be cleaned up with its eventual roboport.)
  if event.destination and event.destination.valid and event.destination.name == PARENT then
    link(event.destination)
  end
end

local function on_destroyed(event)
  ensure_storage()
  local substation = storage.superroboport_children[event.registration_number]
  if substation then
    if substation.valid then substation.destroy() end
    storage.superroboport_children[event.registration_number] = nil
  end
end

-- Re-sync on init and on any mod/config change: ensure every existing superroboport has its
-- substation and is registered (e.g. when this mod is added to an existing save).
local function resync_all()
  ensure_storage()
  for _, surface in pairs(game.surfaces) do
    for _, roboport in pairs(surface.find_entities_filtered{ name = PARENT }) do
      link(roboport)
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
