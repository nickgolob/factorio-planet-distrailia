# Superroboport — requirements

Authoritative list (keep in sync with `superroboport.lua`).

- **One item** that is a roboport **and** a power pole/substation combined.
- **Power area scales with quality** → exactly **50×50 at legendary** (40×40 at normal). Prefer 30x30 normal. 40x40 acceptable if implmeentation of 30x03 is impossible
- **Wire/connection reach: constant 50 tiles** (all qualities).
- **Visible power pole** rising from the centre of the roboport.
- **Fully functional**: distributes power, auto-wires into the grid, powers itself + nearby machines; bots work.
- VISUALLY SHOWS ROBOPORT CONSTRUCTION/LOGISTIC AREAS + POWER AREAS
- VISUALLY SHOWS POWER POLE CONNECTION CABLES + ROBOPORT CONNECTION LINES 
- SHOWS EVERYTHING DURING BUILD PREVIEW, AS WELL AS BEING PLACED.

- PRIOR ART: SPACE-EXPLORATION MOD RADAR CONSTRUCTION PYLON.
- **Preview must exactly match the placed result.**
- **Lifecycle**: roboport + pole created and removed together, no orphans (build / mine / deconstruct / destroy / clone).
