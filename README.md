# Distrailia

> A hellscape of demons and rails.

**Distrailia** is a mod for [Factorio](https://factorio.com) that adds a new modded
planet to the **Space Age** expansion. It is a hostile world where the only way
forward is to lay track across the inferno — a hellscape of demons and rails.

## Status

Early scaffold. The planet is registered on the star map and reachable from Nauvis,
but terrain generation, tiles, enemies, and art are still **TODO**. Not yet
balanced or playable.

## Requirements

- Factorio `>= 2.0`
- Space Age expansion (`space-age`)
- Elevated Rails (`elevated-rails`) — optional, recommended for the theme

## Installation (development)

Clone (or symlink) this repository into your Factorio `mods` folder so the folder
name matches the mod name, `distrailia`:

| OS      | Mods folder |
| ------- | ----------- |
| Windows | `%APPDATA%\Factorio\mods\` |
| macOS   | `~/Library/Application Support/factorio/mods/` |
| Linux   | `~/.factorio/mods/` |

```sh
git clone https://github.com/nickgolob/factorio-planet-distrailia.git distrailia
```

Enable **Distrailia** in the in-game mod manager and restart.

## Roadmap

See [`TODO.md`](TODO.md) for the detailed milestone breakdown and
[`DESIGN.md`](DESIGN.md) for the full design.

- [ ] Custom terrain / tiles (lava, ash, scorched ground)
- [ ] Demon enemies and spawners
- [ ] Rail-centric traversal and resource layout
- [ ] Planet, starmap, and travel art
- [ ] Arrival/departure cutscene procession set
- [ ] Balance pass

## Testing

Static analysis (luacheck) and unit tests run without Factorio; in-game integration tests run
locally via FactorioTest. See [`TESTING.md`](TESTING.md) for install steps and how to run each.

## License

Released under the [MIT License](LICENSE).
