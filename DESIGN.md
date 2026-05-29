# Distrailia - Design

> A hellscape of demons and rails.

> **Rules for this doc**
> - This file records **only** what nick has explicitly dictated - nothing else.
> - Do not add, infer, expand, or "improve" anything he didn't say: no invented
>   mechanics, mods, numbers, or technical approaches.
> - Undecided things stay **TBD (owner: nick)**; don't fill them in.

A modded Space Age planet: a large rail world overrun by enemies. Only the decisions
below are confirmed; the resource chain and exact tuning are **TBD (owner: nick)**.
Roadmap: see [`TODO.md`](TODO.md).

## Worldgen & terrain
- Rail world: large planet, lots of space between resource patches.
- Large lakes of lava.
- Tiles: ash, desert, snow, grass.
- Chasms: a custom cliff-like entity that blocks elevated rails from crossing and is
  indestructible (cannot be destroyed by cliff explosives). Sparse - useful bottlenecks
  that trains must navigate around. Styled as infinite pits of darkness with demonic
  light (custom graphics).
- Solar: 100%.

## Rails
- Functional pre-placed rails: long stretches running this way and that, so the player
  can start by rail-linking outposts.
- Rails and rail signals are invulnerable to enemies.

## Resources & progression
- All Nauvis resources spawn.
- 3 new resources: demonite (ore), hellstone (ore), souls (fluid, pumped by soul extractors).
- Signature mechanic - everything mined rots fast:
  - demonite and hellstone both spoil in ~30 s, and spoil **into enemies** (a demon spawns
    in place, pentapod-egg style). No safe raw stockpile - a backed-up belt, full chest, or
    carried stack breeds demons in your base.
  - souls (the fluid) is the only stable, stockpile-able input.
  - souls, demonite, and hellstone never spawn near each other, so **rail transport is
    required** to move them between the scattered, heavily-defended outposts.
- 1 new science pack (stable/shippable - does not spoil) + tech branch (as per a usual
  modded planet); the superroboport tech sits at the top.
- Full resource chain: TBD (owner: nick) - incl. the stable intermediates, which enemy each
  ore spawns on spoilage, exact spoil time (~30 s baseline), and co-spawn tuning.

## Access
- Outermost world: further out than Secretas.
- Unlock technology: post-Aquilo, costs 2000 cryogenic science.
- Voyage asteroids: the trip out is dense with huge asteroids (plus some big, no promethium),
  ramping up on approach. Parking idle in Distrailia's orbit is calm (no asteroids).

## Enemies & combat
- Lots of enemies: all Nauvis + all Gleba + demolishers (all sizes).
- They repeatedly expand and attack; expand faster and hit harder.
- Artillery is not effective against their expansion.
- Demolishers: scripted attacks (Warptorio2-style).
- Add popular enemy mods (armored biters, etc.).
- Outposts defended with endgame weaponry (tesla turrets, railguns, flamethrowers).

## The reward
- "superroboport": roboport + substation, 50x50 power area, at legendary quality.
