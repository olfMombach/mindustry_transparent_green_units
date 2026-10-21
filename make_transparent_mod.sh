#!/usr/bin/env bash
#
# make_transparent_mod.sh
#
# Assembles a "Transparent Units (Toggle)" mod template for Mindustry:
# - Creates the mod's folder structure.
# - Fetches ALL relevant sprites for aerial construction units
# (the green branch: mono -> poly -> mega -> quad -> oct):
# * Main body (<unit>.png)
# * "Cell"/cockpit (<unit>-cell.png)
# * Weapons (if the unit has a dedicated weapon sprite, as is the case with the poly)
# from the official Anuken/Mindustry repository.
# - Generates "ghost" (semi-transparent) versions using ImageMagick.
# - Creates `mod.json` and `scripts/main.js`, with the F9 key assigned to toggle transparency
# (toggles `region`, `cellRegion`, and weapon regions).
#

# Requirements: curl, ImageMagick (convert)
#

# Usage:
# chmod +x make_transparent_mod.sh
# ./make_transparent_mod.sh [destination_folder] [transparency_0_1]
#

# Example:
# ./make_transparent_mod.sh ./TransparentUnits 0.35

set -euo pipefail

MOD_DIR="${1:-./TransparentUnits}"
ALPHA="${2:-0.1}"   # alpha channel multiplier: 0.0 = invisible, 1.0 = normal opacity

UNITS=(mono poly mega quad oct)

RAW_BASE="https://raw.githubusercontent.com/Anuken/Mindustry/master/core/assets-raw/sprites/units"
RAW_WEAPONS="$RAW_BASE/weapons"

# Units and their specific weapon sprites (taken from the source code: core/src/mindustry/content/UnitTypes.java):
# poly -> "poly-weapon"          (used only by the poly)
# mega -> "heal-weapon-mount"    (used twice by the mega; not found on any other unit)
# mono -> no weapon at all
# quad -> weapon with no sprite (only a bomb effect; no visible barrel)
# oct  -> no weapon at all (only abilities: shield + healing field)
declare -A WEAPON_SPRITE
WEAPON_SPRITE[poly]="poly-weapon"
WEAPON_SPRITE[mega]="heal-weapon-mount"

echo "==> Dependency check"
for bin in curl convert; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Error: utility not found '$bin'. Install it and run the script again." >&2
        echo "  Ubuntu/Debian: sudo apt install curl imagemagick" >&2
        echo "  macOS (brew):  brew install curl imagemagick" >&2
        exit 1
    fi
done

echo "==> Creating a mod structure in '$MOD_DIR'"
mkdir -p "$MOD_DIR/scripts"
mkdir -p "$MOD_DIR/sprites-override/units"

# download_and_ghost <url> <ghost_output_path>
# Downloads the PNG to a temporary file, strips the alpha channel, and places the result in sprites-override/units
download_and_ghost() {
    local url="$1"
    local ghost_path="$2"
    local tmp_path
    tmp_path="$(mktemp --suffix=.png)"

    if ! curl -fsSL "$url" -o "$tmp_path"; then
        echo "     ! Failed to download $url, skipping" >&2
        rm -f "$tmp_path"
        return 1
    fi

    convert "$tmp_path" -channel A -evaluate multiply "$ALPHA" +channel PNG32:"$ghost_path"
    rm -f "$tmp_path"
    return 0
}

echo "==> Downloading sprites and generating transparent versions (alpha=$ALPHA)"

# A transparent "placeholder" for auto-generated outlines (`outlineRegion`) for units and weapons.
# The outline is generated on-the-fly by the engine based on the sprite's pixels. It cannot be downloaded from anywhere, so we simply create a small, completely transparent PNG locally.
BLANK_NAME="transparent-units-blank"
convert -size 8x8 xc:none "PNG32:$MOD_DIR/sprites-override/units/${BLANK_NAME}.png"

# for each unit: body + cell
for unit in "${UNITS[@]}"; do
    echo "   - $unit (body)"
    download_and_ghost "$RAW_BASE/${unit}.png" "$MOD_DIR/sprites-override/units/${unit}-ghost.png" || true

    echo "   - $unit (cell)"
    download_and_ghost "$RAW_BASE/${unit}-cell.png" "$MOD_DIR/sprites-override/units/${unit}-cell-ghost.png" || true
done

# weapons for units that have them, provided as separate, named files
for unit in "${!WEAPON_SPRITE[@]}"; do
    sprite_name="${WEAPON_SPRITE[$unit]}"
    echo "   - $unit (weapon: $sprite_name)"
    download_and_ghost "$RAW_WEAPONS/${sprite_name}.png" "$MOD_DIR/sprites-override/units/${unit}-weapon-ghost.png" || true
done
