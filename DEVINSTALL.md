# Dev install

How to run this mod from source in Factorio (Space Age) during development.

Factorio loads a mod from a folder inside its `mods/` directory whose name matches the
mod's internal name (`distrailia`, from `info.json`). Rather than copying the files in,
we **link** the repo into `mods/` so Factorio reads it live - edit in place, no copy step.

## Factorio mods directory
- Windows: `%APPDATA%\Factorio\mods` (e.g. `C:\Users\<you>\AppData\Roaming\Factorio\mods`)
- macOS:   `~/Library/Application Support/factorio/mods`
- Linux:   `~/.factorio/mods`

## Windows (the method this repo uses)
A **directory junction** (no admin rights required). General form:

```powershell
New-Item -ItemType Junction -Path "$env:APPDATA\Factorio\mods\distrailia" -Target "<path-to-this-repo>"
```

The exact command used to set up this machine:

```powershell
New-Item -ItemType Junction -Path "$env:APPDATA\Factorio\mods\distrailia" -Target "C:\Users\nickg\CODE PROJECTS\distrailia"
```

Quote any path that contains spaces (this repo's path does).

Remove the link later (this deletes only the link, never the repo):

```bat
cmd /c rmdir "%APPDATA%\Factorio\mods\distrailia"
```

> Do not use `Remove-Item -Recurse` on the junction - some PowerShell versions follow it
> into the target and delete the repo. `rmdir` (without `/s`) removes just the link.

## macOS / Linux
A symlink does the same job:

```sh
# Linux
ln -s "<path-to-this-repo>" "$HOME/.factorio/mods/distrailia"

# macOS
ln -s "<path-to-this-repo>" "$HOME/Library/Application Support/factorio/mods/distrailia"
```

## Enable in game
1. Fully restart Factorio (mods load only at startup).
2. Main menu -> Mods -> enable **Distrailia**. Ensure **Space Age** (required) and
   **Elevated Rails** (optional) are also enabled.
3. Confirm / restart to apply.
4. Start a new game with Space Age -> open the star map -> **Distrailia** appears as a
   destination reachable from Nauvis.

If a load fails, Factorio shows the offending mod name and the Lua error at startup.

## Notes
- The folder / junction name must be exactly `distrailia` (it must match `name` in
  `info.json`).
- Non-mod files in the repo (`DESIGN.md`, `TODO.md`, `README.md`, `DEVINSTALL.md`, `.git/`, etc.) are
  ignored by Factorio.
- With a large mod list installed, for a clean test enable only Space Age +
  Elevated Rails + Distrailia.
