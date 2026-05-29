# Distrailia - Design & Implementation Plan

> A hellscape of demons and rails.

A modded Space Age planet built around large distances, relentless multi-faction
enemies, and rail as the backbone of survival. This document captures the agreed
design and how it maps onto Factorio 2.0 / Space Age modding.

The detailed **recipe/resource chain is intentionally TBD** (owner: nick).

> Section 2 and 4 are now confirmed against the Factorio 2.0 prototype/runtime docs
> and existing mods (see References). Remaining items are tuning decisions, not
> feasibility unknowns.

---

## 1. Confirmed design decisions

### Worldgen & terrain
- **Rail world**: large planet, lots of empty space between resource patches.
- **Lava**: lakes of lava (hazard + atmosphere, and a natural barrier - rail
  supports can't be placed on lava, so a wide lava lake also blocks elevated rails).
- **Tiles**: a mix of `ash`, `desert`, `snow`, and `grass` biomes.
- **Chasms**: infinite pits of darkness, lit by an eerie demonic glow - **impassable,
  indestructible (immune to cliff explosives), and not crossable by elevated rails
  either**. Deliberately **sparse** - they act as **chokepoints/bottlenecks the player
  must route ground rail around**, shaping layouts rather than walling everything off.
  Custom graphics planned (see Milestones).
  - Implemented as a custom cliff-like entity (not a real `cliff`, which elevated rails
    would cross) that blocks elevated rails via "too tall" collision - see 2.3.
- **Solar**: 100%.

### Rails (the signature)
- **Functional pre-placed rails**: long, straight-ish stretches running this way and
  that across the surface, generated at worldgen. Purpose: give the player a head
  start and make **rail travel between outposts the core logistics method**.
- **Rails and rail signals are invulnerable to enemies** (cannot be destroyed by
  enemy attacks; still player-minable/deconstructable).
- **Recommended companion mod: [Moshine](https://mods.factorio.com/mod/Moshine)** (not a
  dependency) - adds maglev trains and neodymium rails (including neodymium *elevated*
  rails), a great fit for the rail fantasy. Note: the chasm "too tall" collision (2.3)
  should block its elevated rails too - verify when integrating.

### Resources & progression
- **All Nauvis resources spawn**: iron, copper, coal, stone, crude oil, uranium.
- **3 new resources**: `demonite` (ore), `hellstone` (ore), `souls` (fluid, pumped).
- **1 new science pack** (Distrailia science) plus a tech branch, as per a usual
  modded planet. The endgame tech sits at the top of this branch.
- **Full recipe/resource chain: TBD.**

### Access & star map
- **Outermost world**: placed beyond Secretas (distance 50, vs. Secretas 45) on the
  star map, reached via a Nauvis space connection.
- **Gated by a discovery technology** (implemented in M1): travel unlocks only after
  researching *Planet discovery: Distrailia* - prerequisites `planet-discovery-aquilo`
  + `cryogenic-science-pack`, cost **2000 cryogenic science**. Squarely post-Aquilo
  endgame content.

### Enemies & combat
- **LOTS of enemies**, three factions combined:
  - All Nauvis enemies (biters, spitters, worms, spawners)
  - All Gleba enemies (pentapods / stompers, wrigglers, spawners)
  - Demolishers, **all sizes** (small / medium / big)
- **Expansion: faster and harder.** Crank expansion frequency/group size and buff
  enemy damage/health. This *is* the reason **artillery is ineffective** - the
  enemies simply out-expand and out-hit what artillery can suppress; no special
  artillery mechanic needed.
- **Demolishers: scripted attacks** (Warptorio-style). A `control.lua` "director"
  periodically spawns demolishers and aims them at player bases.
- **Popular enemy-mod integration**: optionally fold in enemies from popular mods
  (Armoured Biters, etc.) - see 2.6.
- Every outpost must be **heavily defended with endgame weaponry**: tesla turrets,
  railguns, flamethrowers (all exist in Space Age - we balance enemies around them).

### The ultimate reward
- **"superroboport"**: a combined **roboport + substation** with a **50x50 power
  supply area**, obtained at **legendary quality**. Capstone of the tech branch.

---

## 2. Technical approach (confirmed)

### 2.1 Planet & surface (`prototypes/planet.lua` - already scaffolded)
- Extend the existing `planet` + `space-connection` prototypes.
- `surface_properties`: `solar-power = 100` (currently `50`); tune gravity/pressure.
- `map_gen_settings` drives terrain, resources, enemies, chasms.

### 2.2 Terrain & tiles (`prototypes/tiles.lua`, `prototypes/map-gen.lua`)
- MVP: reuse existing tiles, autoplaced by climate noise - grass (base `grass-*`),
  desert (`sand-*` / `red-desert-*`), snow (Aquilo tiles), ash (Vulcanus volcanic
  tiles). Custom art later.
- **Lava lakes**: autoplace the Space Age `lava` tile in **large** patches; these
  double as natural barriers (supports can't sit on lava, and a wide lake can't be spanned).
- **Rail-world spacing**: low resource frequency + larger size so patches are far apart.

### 2.3 Chasms / chokepoints (`prototypes/chasms.lua`)
**Locked design**: chasms are a custom **cliff-like impassable entity** (not a real
`cliff` prototype), styled as an infinite pit of darkness with a demonic glow. As an
entity we get exactly the behavior we want:
- **Impassable on the ground**: blocking collision box, `minable = false`, indestructible.
- **Immune to cliff explosives**: it is not `type = "cliff"`, so the `destroy-cliffs`
  effect has nothing to target and there is no robot/planner removal.
- **Blocks elevated rails**: give it the collision layer that makes "too tall" entities
  (roboports, big electric poles) block elevated-rail construction, so elevated rails
  cannot be built across it even when narrow. Exact layer taken from
  `UtilityConstants.default_collision_masks` at build time.
- Autoplaced **sparsely** as chokepoints; demonic light via a `light` definition on the
  entity (or light-emitting decoratives around the rim).

Why not a real `cliff`: elevated rails cross cliffs (and water) by design, and cliffs
can be cliff-exploded - both of which we want to avoid. (Large lava lakes remain a
secondary natural barrier: rail supports can't sit on lava.)

Graphics (deep-void interior, lit rim, demonic light sources) are a dedicated milestone.

### 2.4 Resources (`prototypes/resources.lua`)
- `demonite`, `hellstone`: `type = "resource"` (solid), each with `item`, icon, result.
- `souls`: `type = "fluid"` + a `type = "resource"` with `category = "basic-fluid"`
  so it is **pumpjack-pumped** like crude oil.
- Nauvis ores: enable their autoplace controls in the planet `map_gen_settings`.
- Refining recipes: **TBD**.

### 2.5 Science & tech (`prototypes/science.lua`, `prototypes/technology.lua`)
- New science-pack `tool` item (used in existing labs), produced from Distrailia
  resources (chain TBD).
- Tech branch requiring Distrailia science; the **superroboport** tech is the top.
- **Planet-discovery tech** (`planet-discovery-distrailia`, done in M1): effect
  `unlock-space-location -> distrailia`, prerequisites `planet-discovery-aquilo` +
  `cryogenic-science-pack`, cost 2000 cryogenic science. A space location referenced by
  such a tech is **locked until researched**, which is what gates travel to Distrailia.

### 2.6 Enemies, expansion & mod integration (`prototypes/enemies.lua`, `control.lua`)
- Add Nauvis + Gleba enemies to the planet's enemy autoplace; crank
  `map_gen_settings.enemy_expansion` (frequency/group size/cooldown) + evolution and
  buff unit damage/health -> "faster and harder".
- **Demolishers**: spawn via `LuaSurface.create_segmented_unit{ name = "big-demolisher"
  | "medium-demolisher" | "small-demolisher", position = ..., force = "enemy" }` - the
  correct 2.0 API for segmented units (works in ungenerated chunks; `territory = nil`
  -> patrols its spawn). A director sends waves at the nearest player base.
- **Optional enemy mods** (confirmed current on 2.0/Space Age), added as `?` deps and
  merged into spawn lists only if installed:
  - Armoured Biters ("Snappers"), Explosive Biters, Toxic Biters, Frost Biters.
  - Companions/inspiration: B.R.E.A.M. (multi-faction Nauvis+Gleba spawn manager),
    Enemy AI Enhancement (smarter AI, auto-detects modded enemies).
  - Generic auto-detect (read each spawner's `result_units` / enemy subgroup) so any
    installed enemy mod is folded in without per-mod code.

### 2.7 Functional pre-placed rails (`control.lua`)
- Prototypes: `straight-rail`, `half-diagonal-rail`, `curved-rail-a`/`-b`; signals
  `rail-signal`, `rail-chain-signal`. **2x2 grid** (`build_grid_size = 2`); connection
  points sit on integer coordinates.
- On `on_chunk_generated`, lay runs of `straight-rail` (cardinal, + optional curves)
  aligned to the 2x2 grid so track wanders "this way and that". Keep stretches bounded.
- **Gotcha**: a rail's `.position` is the 2x2 grid center and its collision box is
  off-center, so locating rails must **search an area**, not a single point.

### 2.8 Rails invulnerable to enemies (`control.lua`)
- Prototype invuln is global, so scope it at runtime: on build / chunk-gen /
  script-raised events, for rail + rail-signal entities on the Distrailia surface, set
  `entity.destructible = false` (blocks enemy damage, still mineable). Use the
  area-search from 2.7 to catch pre-placed rails.

### 2.9 Superroboport (`prototypes/entities/superroboport.lua` + `control.lua`)
- Confirmed precedent: the "Utility Station" mod puts an **uninteractable substation
  under a roboport** with no UPS cost. Same pattern here:
  - Main `roboport` (interactable, blueprintable, large logistic/construction radius).
  - Hidden `electric-pole` substation with `supply_area_distance = 25` -> **50x50**
    (max allowed is 64).
  - `control.lua` sync: create the hidden pole on build, set its `minable = false` /
    `destructible = false`, and destroy it with the parent (mined / died /
    `register_on_entity_destroyed`).
- **Legendary**: vanilla substation supply area scales 18x18 -> 28x28 at legendary
  (`supply_area_distance` 9 -> 14). Two options:
  - (a) Simplest: fix the hidden pole at `25` (50x50 at all qualities) and gate the
    recipe to legendary.
  - (b) Quality-scaled: set the base lower so legendary lands at 25; confirm in-game
    whether the quality bonus is flat (+5 like vanilla) or proportional.

---

## 3. Proposed file structure

```
distrailia/
├─ info.json                     + optional enemy-mod dependencies
├─ data.lua                      requires all prototype files below
├─ settings.lua                  (optional) map-gen / integration toggles
├─ control.lua                   NEW: rail gen + invuln, demolisher director,
│                                 superroboport linking, enemy-mod spawn hookup
├─ changelog.txt
├─ prototypes/
│  ├─ planet.lua                 planet + space-connection (exists; expand)
│  ├─ map-gen.lua                autoplace orchestration
│  ├─ tiles.lua                  ash/desert/snow/grass + lava lakes
│  ├─ chasms.lua                 sparse cliff-like impassable entity (blocks elevated rails)
│  ├─ resources.lua              demonite, hellstone, souls (+ fluid/items)
│  ├─ science.lua                Distrailia science pack
│  ├─ technology.lua             tech branch (superroboport at the top)
│  ├─ enemies.lua                enemy lists, expansion, resistances, mod integration
│  └─ entities/
│     └─ superroboport.lua       roboport + hidden substation, item, recipe
├─ locale/en/distrailia.cfg      names/descriptions for everything new
└─ graphics/                     art (placeholder -> polish pass)
```

---

## 4. Status of the earlier risk items

All five earlier unknowns are resolved to a concrete approach:
1. **Indestructible chasms** - locked to a custom cliff-like entity (not a real
   `cliff`): impassable, immune to cliff explosives, and blocks elevated rails via
   "too tall" collision. 2.3.
2. **Superroboport** - solved via roboport + hidden substation (`supply_area_distance
   = 25`), precedent exists. 2.9.
3. **Rail invulnerability** - `destructible = false` at runtime + area-search. 2.8.
4. **Artillery ineffective** - design choice: faster/harder expansion. 2.6.
5. **Demolishers** - `create_segmented_unit` + director. 2.6.

### Remaining tuning decisions (not blockers)
- Chasm entity: confirm the exact "too tall" collision-layer name from
  `UtilityConstants.default_collision_masks` (approach is locked; this is just a lookup).
- Superroboport quality scaling: flat-25 vs base-scaled-to-legendary.
- Exact enemy tuning numbers (expansion rates, stat buffs, demolisher cadence).
- Final enemy-mod list; hard-integrate B.R.E.A.M./Enemy AI Enhancement vs auto-detect.
- Demolisher targeting (patrol-near-base vs scripted pathing).

---

## 5. Milestones

- **M1 - Loadable planet**: planet + connection, reused tiles, small lava lakes,
  Nauvis ores, solar 100%, travel from Nauvis works.
- **M2 - Hostile world**: Nauvis + Gleba + demolisher enemies, faster/harder
  expansion, demolisher director, endgame-turret balance, optional enemy-mod hooks.
- **M3 - New resources + science**: demonite, hellstone, souls (fluid + pumpjack),
  Distrailia science pack + tech branch skeleton.
- **M4 - Rails & chasms**: functional pre-placed rail stretches + rail/signal
  invulnerability + sparse impassable chasms (placeholder art).
- **M5 - Chasm visuals**: bespoke "infinite pit of darkness" graphics (deep-void
  interior, lit rim / edge transitions) + demonic light sources.
- **M6 - Reward**: superroboport composite at legendary, recipe/tech gating.
- **M7 - Polish**: custom tile/entity art, sound, balance pass.

---

## 6. TBD (owner: nick)
- Full **resource -> intermediate -> product chain**, including the Distrailia
  science-pack recipe and how the chain gates the superroboport.
- Exact **enemy tuning** numbers.
- Final **enemy-mod list** to integrate.

---

## References
- CliffPrototype / `cliff_explosive`: https://lua-api.factorio.com/latest/prototypes/CliffPrototype.html
- DestroyCliffsTriggerEffectItem (`destroy-cliffs`): https://lua-api.factorio.com/latest/types/DestroyCliffsTriggerEffectItem.html
- ElectricPolePrototype (`supply_area_distance`, max 64): https://lua-api.factorio.com/latest/prototypes/ElectricPolePrototype.html
- Quality scaling (substation 18x18 -> 28x28): https://wiki.factorio.com/Quality
- Utility Station (roboport+substation precedent): https://github.com/dmikalova/factorio-mods/tree/main/utility-station
- LuaSurface.create_segmented_unit: https://lua-api.factorio.com/latest/classes/LuaSurface.html
- Rail prototypes / 2x2 grid: https://lua-api.factorio.com/latest/prototypes/HalfDiagonalRailPrototype.html
- Elevated rails / rail support (crosses cliffs+water; support span): https://wiki.factorio.com/Rail_support
- FFF #378 - elevated rails: https://factorio.com/blog/post/fff-378
- CollisionMask (2.0 named layers): https://lua-api.factorio.com/latest/concepts/CollisionMask.html
- RailSupportPrototype (support_range): https://lua-api.factorio.com/latest/prototypes/RailSupportPrototype.html
- Warptorio 2.0 (Space Age): https://mods.factorio.com/mod/warptorio-space-age
- Armoured Biters: https://mods.factorio.com/mod/ArmouredBiters
- Enemy AI Enhancement: https://mods.factorio.com/mod/smart-enemy-ai
- B.R.E.A.M.: https://mods.factorio.com/mod/BREAM
- Moshine (recommended - maglev trains + neodymium rails): https://mods.factorio.com/mod/Moshine
