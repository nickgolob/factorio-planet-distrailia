# Distrailia - TODO

> A hellscape of demons and rails.

Roadmap for the Distrailia planet mod. Design: see [`DESIGN.md`](DESIGN.md).
Status: `[x]` done, `[ ]` todo.

### M1 - Loadable planet  (done)
- [x] Planet (deep-copied from Nauvis), 100% solar, outermost slot beyond Secretas.
- [x] Nauvis space connection.
- [x] Discovery tech: post-Aquilo, 2000 cryo science, unlocks travel.

### M2 - Enemies
- [ ] All Nauvis + all Gleba enemies + demolishers (all sizes).
- [ ] Expand faster, attack harder; artillery ineffective.
- [ ] Scripted demolisher attacks (Warptorio2-style).
- [ ] Optional deps on popular enemy mods (armored biters, etc.).

### M3 - Resources & science
- [ ] All Nauvis resources spawn.
- [ ] demonite (ore), hellstone (ore), souls (fluid, pumped).
- [ ] Spoilage: demonite + hellstone spoil (~30 s) into enemies; on-site processing with
  souls -> stable intermediates; souls is the only stable input.
- [ ] 1 new science pack (stable) + tech branch.
- [ ] Resource chain (TBD, owner: nick).

### M4 - Terrain, rails & chasms
- [ ] Tiles: ash, desert, snow, grass.
- [ ] Large lava lakes.
- [ ] Rail-world spacing (large, resources far apart).
- [ ] Chasms: cliff-like entity, indestructible, blocks elevated rails, sparse bottlenecks.
- [ ] Pre-placed functional rails (long stretches).
- [ ] Rails + rail signals invulnerable to enemies.

### M5 - Visuals
- [ ] Custom Distrailia icon (planet + starmap).
- [ ] Chasm graphics (pits of darkness, demonic light).
- [ ] Superroboport graphics: bespoke item/entity icon and on-map art (currently a placeholder
  roboport + substation-badge composite).

### M6 - Reward
- [x] superroboport: the placed entity is a power POLE wearing the roboport building sprite (SE
  Construction Pylon pattern); a hidden roboport is spawned under it (control.lua) for the bots +
  construction/logistic radius. Power area scales 40x40 normal -> 50x50 legendary (engine pole bonus),
  wire reach constant 50; tech + recipe + build/remove lifecycle. Integration-tested
  (prototypes/entities/superroboport/superroboport_test.lua).
- [ ] Final legendary-quality gating + recipe/tech wired to the M3 resource chain
  (demonite / Distrailia science). Currently placeholder ingredients, gated behind reaching Distrailia.
- [ ] R-PREVIEW residue: the cursor shows the roboport sprite + power area + copper cables, but NOT
  the roboport's construction/logistic radius squares or network lines (those come from the hidden
  roboport, which only exists after build). Full "show everything" is not satisfiable with stock 2.0
  modding -- see superroboport-approaches.md.
