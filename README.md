# Transparent Units (Toggle)

A Mindustry mod that lets you toggle transparency on the green support/build
air unit line — **Mono, Poly, Mega, Quad, Oct** — with a single hotkey,
directly in-game. No restart required.

## Features

- **F9** toggles all five units between normal and (semi-)transparent, live,
  mid-game.
- Covers the full visual footprint of each unit, not just the main body:
  - main body sprite
  - "cell" (cockpit) sprite
  - engine thruster glow (procedural color, not a texture)
  - weapon sprite, where one exists (Poly, Mega)
  - the auto-generated black outline around the body and weapons
- A toast notification confirms the current state when you toggle.

## Requirements

- Mindustry **v154** or newer (`minGameVersion` is set accordingly in
  `mod.json`).
- Desktop or Android — mods with scripts are not supported on iOS due to
  App Store restrictions.

## Installation

**Option A — from a `.zip` release**
1. Download the mod as a `.zip`.
2. In-game: **Menu → Mods → Import Mod**, then select the file.

**Option B — from this GitHub repo**
1. In-game: **Menu → Mods → Import Mod**, then type the repository name
   (e.g. `yourname/transparent-units-toggle`).

## Usage

1. Load into any map or sandbox.
2. Press **F9** at any time to toggle visibility of Mono, Poly, Mega, Quad,
   and Oct.
3. Press it again to restore normal visibility.

## Known limitations

- The toggle affects **the unit type as a whole**, not just your own units —
  since region/color swapping happens on the shared `UnitType` object,
  enemy units of the same type are affected too.
- Only Poly and Mega have a distinct weapon sprite in vanilla Mindustry, so
  only those two get weapon-specific transparency. Mono has no weapon at
  all; Quad's weapon has no mount sprite (only a bomb-drop effect); Oct has
  no weapons, only ability-driven effects (shield, repair field) which are
  not sprite-based and can't be hidden this way.
- Ability effects (shields, repair fields, bomb explosions) are drawn as
  procedural effects, not textures, and are not affected by this mod.

## Building from source / regenerating sprites

This repo includes `make_transparent_mod.sh`, the script used to scaffold
the mod: it downloads the vanilla sprites for the five target units from the
official [Anuken/Mindustry](https://github.com/Anuken/Mindustry) repository,
generates semi-transparent ("ghost") versions of them via ImageMagick, and
writes `mod.json` and `scripts/main.js`.

```bash
chmod +x make_transparent_mod.sh
./make_transparent_mod.sh ./TransparentUnits 0.1
```

- First argument: output folder for the mod.
- Second argument: alpha multiplier (`0.0` = fully invisible, `1.0` =
  normal opacity). Default is `0.1`.

Requires `curl` and ImageMagick (`convert`) to be installed.

## Credits

- Built on top of vanilla Mindustry assets and API by
  [Anuken](https://github.com/Anuken).
- Sprites are unmodified-in-content, alpha-adjusted copies of the original
  vanilla sprites; no new artwork is included.

## License

Distributed as-is for personal/community use. Vanilla sprite assets remain
subject to the original Mindustry project's licensing terms.
