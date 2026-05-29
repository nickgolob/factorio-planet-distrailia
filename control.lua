-- Distrailia runtime scripting.
--
-- Superroboport linking. The superroboport (prototypes/entities/superroboport.lua) is a
-- roboport prototype; its 50x50 power area comes from a hidden, indestructible substation
-- spawned underneath it here. The pair must live and die together:
--   * on every build path we create (or adopt) the hidden substation under the roboport;
--   * when the roboport is removed by any means -- mined, died, deconstructed, scripted,
--     surface cleared -- register_on_object_destroyed fires and we destroy the substation.
--
-- The hidden substation is spawned at the roboport's own quality so its supply area scales with
-- quality: base 20 + (quality level) gives 40x40 at normal up to 25 -> 50x50 at legendary
-- (DESIGN.md "The reward", quality-scaling option). If a stale substation's quality drifts from its roboport, we rebuild it.
--
-- register_on_object_destroyed -> on_object_destroyed reference:
--   https://lua-api.factorio.com/latest/classes/LuaBootstrap.html

local PARENT = "superroboport"
local CHILD = "superroboport-substation"

local function ensure_storage()
  storage.superroboport_children = storage.superroboport_children or {}
end

-- Create (or adopt an already-present) hidden substation under a superroboport and tie its
-- lifetime to the roboport. Idempotent: safe to call again for the same roboport.
local function link(roboport)
  if not (roboport and roboport.valid and roboport.name == PARENT) then return end
  ensure_storage()
  local surface = roboport.surface
  local found = surface.find_entities_filtered{ name = CHILD, position = roboport.position, radius = 0.1 }
  local substation = found[1]
  -- Rebuild a stale substation whose quality no longer matches the roboport, so the supply area
  -- always tracks the roboport's quality.
  if substation and substation.valid and substation.quality.name ~= roboport.quality.name then
    substation.destroy()
    substation = nil
  end
  if not (substation and substation.valid) then
    substation = surface.create_entity{
      name = CHILD,
      position = roboport.position,
      force = roboport.force,
      quality = roboport.quality, -- scale the supply area with the roboport's quality
    }
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
  -- it is unselectable/indestructible and will be cleaned up with its eventual roboport.)
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
