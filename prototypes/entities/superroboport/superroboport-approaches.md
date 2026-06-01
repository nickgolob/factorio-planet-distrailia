# Superroboport — implementation options & tradeoffs

Decision record for the superroboport (a combined roboport + power pole). Requirements live in
`REQUIREMENTS.md`; the one everything trips on:

> **R‑PREVIEW:** the build cursor should show **all** of {roboport sprite, roboport
> construction/logistic areas, roboport network lines, power supply area, power cables}, and the
> preview must match what is placed.

Other constraints referenced below: **R‑SPRITE** cursor shows the superroboport's own sprite (not a
bare vanilla pole/roboport); **R‑SCALE** 50×50 supply at legendary (30×30 floor preferred, 40×40
acceptable); **R‑WIRE** constant 50 wire reach; **R‑FUNC** powers itself + grid + bots; **R‑LIFE**
the two halves build/remove together.

---

## 1. The root engine constraint

The build cursor draws the **type‑specific** previews of **exactly one placed entity of one
prototype type**. `roboport` and `electric-pole` are different, mutually‑exclusive types:

| Cursor of… | draws | does NOT draw |
| --- | --- | --- |
| `electric-pole` | pole sprite, **supply‑area** square, **copper‑wire** connection lines | robot areas, roboport network lines |
| `roboport` | building sprite, **construction + logistic** areas, **dotted network** connection lines | supply area, copper cables |

Escape hatches and why they don't fully work:
- `radius_visualisation_picture` (pole) draws only the **supply area** — not robot areas, not lines, not a sprite.
- `radius_visualisation_specification` is **not** a field on `electric-pole` (verified in the prototype docs) — so a pole cursor can't borrow a roboport‑area ring either.
- A custom cursor‑following overlay via `rendering` is **impossible**: a normal game exposes no API to read/set the cursor world position (only tutorial `LuaSimulation` can), and Factorio **ignores injected OS mouse input** (raw input) — verified: focusing the window + `SetCursorPos`/`mouse_event` never moved `player.selected`.
- No prototype type is *both* a roboport and a pole; an entity has exactly one `type`.

**Conclusion:** no single placed entity (and no scripted overlay) can satisfy R‑PREVIEW in full. The
cursor can show the pole side **or** the roboport side — not both.

### Space Exploration does NOT do "both" (verified first‑hand)
Read from SE 0.7.56 source (`prototypes/phase-1/entity/pylons.lua` + `scripts/composites.lua`): SE's
**Construction Pylon is the identical technique to Option A** here, not a both‑at‑once trick:
- `se-pylon-construction` is `type = "electric-pole"` (the placed entity) with `radius_visualisation_picture` (supply‑area sprite), `supply_area_distance`, `maximum_wire_distance = 64` — i.e. its cursor previews the **pole side** (supply area + copper cables).
- `se-pylon-construction-roboport` is `type = "roboport"`, **`hidden = true`, `selectable_in_game = false`**, with `draw_construction_radius_visualization = true`. It's spawned at the pole's position by `composites.lua` `on_entity_created` and destroyed with it — exactly our `control.lua`.

Because the roboport half is hidden + non‑selectable, **SE's cursor shows only the pole side**; the
roboport construction/logistic areas and network lines do **not** appear in the pylon's build cursor.
SE's separate "placement preview" helper toggles range *instead of* wires — never both at once. So
there is no SE technique to copy; "both in one cursor" is a genuine engine limit.

---

## 2. Composite architecture options

Both live options are a **two‑entity composite**: one placed (`place_result`, drives the cursor +
selection), one hidden child spawned by `control.lua` (R‑LIFE: built/removed together).

### Option A — Pole‑primary (CURRENT)
Placed = `electric-pole "superroboport"` wearing a **merged roboport‑base + mast sprite**; hidden
child = `roboport "superroboport-roboport"`.

- **Cursor:** merged sprite + **supply area** + **copper cables**. ✓ R‑SPRITE, power/cable preview.
- **Placed:** all of the above + bots work (hidden roboport). Robot areas/lines exist but the hidden roboport is non‑selectable, so they never show even on hover.
- **R‑SCALE:** engine electric‑pole bonus (+1/level) on `supply_area_distance = 20` → 40×40 normal, 50×50 legendary. preview == placed. (30×30 floor not possible this way — see §4.)
- **Pros:** simplest; power area + cables preview live; preview == placed for the pole side.
- **Cons:** cursor shows **no** roboport areas and **no** dotted network lines. (This is the v2 gap.)

### Option B — Roboport‑primary
Placed = `roboport "superroboport"` wearing the merged sprite; hidden child = `electric-pole`.

- **Cursor:** merged sprite + **construction area + logistic area + dotted roboport network lines**. ✓ the v2 ask.
- **Placed:** above + the hidden pole auto‑connects **copper cables** and distributes power.
- **R‑SCALE:** supply area is the **hidden pole's**, so quality scaling needs the pole spawned at the right quality (doable); or fixed.
- **Pros:** cursor shows the roboport network connectivity + areas (what you check when placing a roboport); arguably the more useful placement preview.
- **Cons:** cursor shows **no** supply area and **no** copper cables (they appear only on placement); bigger rework (swap placed/hidden, sprite host, tests); preview ≠ placed for the power side.

### Non‑viable options (history)
| Approach | Why rejected |
| --- | --- |
| Single entity that is both types | No such prototype `type` exists. |
| Pole placed with invisible sprite | Fails R‑SPRITE; also `empty_sprite` isn't a valid `RotatedSprite`. |
| On‑build entity swap (preview entity → real variant) | Breaks "preview must match placed" (previewed thing is destroyed). |
| Five per‑quality items | Breaks the Quality module mechanic; still one type each → still no both‑sides cursor. |
| Per‑quality variants spawned at normal (data‑final‑fixes) | Gets 30×30 floor but breaks preview==placed; high complexity. |
| Custom `rendering` cursor overlay | No cursor world‑position API; injected mouse ignored. |

---

## 3. The cursor matrix (the active v2 decision)

| Visual element | Pole‑primary (A) cursor | Roboport‑primary (B) cursor | When PLACED (either) |
| --- | :---: | :---: | :---: |
| Merged roboport + mast sprite | ✅ | ✅ | ✅ |
| Power **supply area** | ✅ | ❌ | ✅ works |
| **Copper cables** | ✅ | ❌ | ✅ auto‑connect |
| **Construction** area | ❌ | ✅ | hidden |
| **Logistic** area | ❌ | ✅ | hidden |
| **Dotted** roboport network lines | ❌ | ✅ | hidden |

> The choice is purely **which side the cursor previews**. Everything functions identically once
> placed; only the *preview* differs. "Show everything in one cursor" remains impossible (§1).

---

## 4. Quality‑scaling options (R‑SCALE)

| Option | Result | Tradeoff |
| --- | --- | --- |
| Engine bonus on a single prototype (CURRENT) | `supply_area_distance=20` → **40→50** by quality | Simplest; preview == placed. Floor is 40, not 30. |
| Per‑quality prototypes spawned at normal quality | exact **30→50** | Breaks preview == placed (placed swaps to a fixed‑quality variant); more prototypes. |

`REQUIREMENTS.md` allows 40×40 when 30×30 is impossible without breaking preview==placed, so the
engine‑bonus option is the chosen one.

---

## 5. Visual‑test / golden capture options (how we *see* it)

`take_screenshot` only renders with a graphics thread, on the visible desktop. Tradeoffs by goal:

| Capture | What it gets | Cost / limit |
| --- | --- | --- |
| Off‑screen isolated instance (`run.ps1`) | placed sprite, real cables (`01-sprite`, `02-network`) | window parked off‑screen; **can't** capture hover/cursor overlays |
| On‑screen + your real mouse (`run.ps1 -Cursor`) | the **real build‑cursor** preview (`cursor.png`) | brief on‑screen window; needs ~a few seconds of your mouse (injected mouse is ignored) |
| In‑game `/distrailia-cursor-shot` | same, from your live game | one trigger with your real mouse |
| Injected OS mouse (scripted) | — | **fails**: Factorio ignores synthetic mouse (raw input) — verified |
| `LuaSimulation` (programmatic cursor) | could set cursor + capture | only exists inside a tutorial/menu **simulation**, which the test harness can't launch |

Goldens are committed under `golden/` (Git LFS). Steam's graphics client needs `steam_appid.txt`
(the runner creates it); the isolated `--mod-directory` keeps it off your live save/mods.

---

## 6. Open decision

**v2 cursor — pick the cursor's side (§3):**
- **Stay Option A (pole‑primary):** keep supply‑area + copper‑cable preview; **no** dotted roboport lines in the cursor.
- **Flip to Option B (roboport‑primary):** gain construction/logistic areas + **dotted network lines** in the cursor; lose the supply‑area + cable preview in the cursor (still auto‑connect/work on placement). Requires swapping placed/hidden halves, moving the sprite host, and updating the tests.

Everything else (sprite, R‑WIRE, R‑FUNC, R‑LIFE, R‑SCALE @ 40→50, the capture tooling) is settled
and independent of this choice.
