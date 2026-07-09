#!/usr/bin/env bash
#
# make_transparent_mod.sh
#
# Собирает мод-заготовку "Transparent Units (Toggle)" для Mindustry:
#   - создаёт структуру папок мода
#   - тянет ВСЕ связанные спрайты воздушных строительных юнитов
#     (зелёная ветка: mono -> poly -> mega -> quad -> oct):
#       * основной корпус (<unit>.png)
#       * "ячейку"/кабину (<unit>-cell.png)
#       * оружие, если у юнита есть именной спрайт оружия (у poly)
#     из официального репозитория Anuken/Mindustry
#   - генерирует "призрачные" (полупрозрачные) версии через ImageMagick
#   - пишет mod.json и scripts/main.js с хоткеем F9 для переключения
#     (переключает region, cellRegion и регионы оружия)
#
# Требования: curl, ImageMagick (convert)
#
# Использование:
#   chmod +x make_transparent_mod.sh
#   ./make_transparent_mod.sh [папка_назначения] [прозрачность_0_1]
#
# Пример:
#   ./make_transparent_mod.sh ./TransparentUnits 0.35

set -euo pipefail

MOD_DIR="${1:-./TransparentUnits}"
ALPHA="${2:-0.1}"   # множитель альфа-канала: 0.0 = невидимо, 1.0 = обычная непрозрачность

UNITS=(mono poly mega quad oct)

RAW_BASE="https://raw.githubusercontent.com/Anuken/Mindustry/master/core/assets-raw/sprites/units"
RAW_WEAPONS="$RAW_BASE/weapons"

# Юниты и их именные спрайты оружия (взято из исходников core/src/mindustry/content/UnitTypes.java):
#   poly -> "poly-weapon"          (используется только у poly)
#   mega -> "heal-weapon-mount"    (используется дважды у mega, у других юнитов не встречается)
#   mono -> оружия нет вообще
#   quad -> оружие без спрайта (только бомба-эффект, видимого ствола нет)
#   oct  -> оружия нет вообще (только способности: щит + лечащее поле)
declare -A WEAPON_SPRITE
WEAPON_SPRITE[poly]="poly-weapon"
WEAPON_SPRITE[mega]="heal-weapon-mount"

echo "==> Проверка зависимостей"
for bin in curl convert; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "Ошибка: не найдена утилита '$bin'. Установи её и запусти скрипт снова." >&2
        echo "  Ubuntu/Debian: sudo apt install curl imagemagick" >&2
        echo "  macOS (brew):  brew install curl imagemagick" >&2
        exit 1
    fi
done

echo "==> Создание структуры мода в '$MOD_DIR'"
mkdir -p "$MOD_DIR/scripts"
mkdir -p "$MOD_DIR/sprites-override/units"

# download_and_ghost <url> <ghost_output_path>
# Скачивает PNG во временный файл, режет альфа-канал, кладёт результат в sprites-override/units
download_and_ghost() {
    local url="$1"
    local ghost_path="$2"
    local tmp_path
    tmp_path="$(mktemp --suffix=.png)"

    if ! curl -fsSL "$url" -o "$tmp_path"; then
        echo "     ! Не удалось скачать $url, пропускаю" >&2
        rm -f "$tmp_path"
        return 1
    fi

    convert "$tmp_path" -channel A -evaluate multiply "$ALPHA" +channel PNG32:"$ghost_path"
    rm -f "$tmp_path"
    return 0
}

echo "==> Скачивание спрайтов и генерация прозрачных версий (alpha=$ALPHA)"

# Прозрачная "заглушка" для авто-генерируемых обводок (outlineRegion) юнитов и оружия.
# Обводка генерируется движком на лету из пикселей спрайта, скачать её негде -
# поэтому просто создаём маленький полностью прозрачный PNG локально.
BLANK_NAME="transparent-units-blank"
convert -size 8x8 xc:none "PNG32:$MOD_DIR/sprites-override/units/${BLANK_NAME}.png"

# по каждому юниту: тело + ячейка
for unit in "${UNITS[@]}"; do
    echo "   - $unit (body)"
    download_and_ghost "$RAW_BASE/${unit}.png" "$MOD_DIR/sprites-override/units/${unit}-ghost.png" || true

    echo "   - $unit (cell)"
    download_and_ghost "$RAW_BASE/${unit}-cell.png" "$MOD_DIR/sprites-override/units/${unit}-cell-ghost.png" || true
done

# оружие для юнитов, у которых оно есть отдельным именным файлом
for unit in "${!WEAPON_SPRITE[@]}"; do
    sprite_name="${WEAPON_SPRITE[$unit]}"
    echo "   - $unit (weapon: $sprite_name)"
    download_and_ghost "$RAW_WEAPONS/${sprite_name}.png" "$MOD_DIR/sprites-override/units/${unit}-weapon-ghost.png" || true
done

echo "==> Запись mod.json"
cat > "$MOD_DIR/mod.json" <<EOF
{
  "name": "transparent-units-toggle",
  "displayName": "Transparent Units (Toggle)",
  "author": "you",
  "description": "F9 - переключить прозрачность юнитов зелёной ветки (mono/poly/mega/quad/oct), включая ячейку, оружие и сопла",
  "version": "1.0",
  "minGameVersion": "154"
}
EOF

echo "==> Запись scripts/main.js"
cat > "$MOD_DIR/scripts/main.js" <<'EOF'
// Юниты зелёной (строительной/support) воздушной ветки.
// hasWeaponSprite=true - у юнита есть именной файл оружия со стволом (poly, mega).
var targets = [
    { type: UnitTypes.mono, name: "mono", hasWeaponSprite: false },
    { type: UnitTypes.poly, name: "poly", hasWeaponSprite: true },
    { type: UnitTypes.mega, name: "mega", hasWeaponSprite: true },
    { type: UnitTypes.quad, name: "quad", hasWeaponSprite: false },
    { type: UnitTypes.oct,  name: "oct",  hasWeaponSprite: false }
];

var visible = true; // true = обычные спрайты, false = прозрачные
var blankRegion = null; // прозрачная заглушка для авто-обводок

function findRegion(name) {
    var r = Core.atlas.find(name);
    if (r == null) {
        Log.warn("[transparent-units] не найден спрайт: " + name);
    }
    return r;
}

Events.on(ClientLoadEvent, function(e) {
    for (var i = 0; i < targets.length; i++) {
        var t = targets[i];

        // основной корпус
        t.normalRegion = t.type.region;
        t.ghostRegion = findRegion(t.name + "-ghost");

        // "ячейка"/кабина
        t.normalCell = t.type.cellRegion;
        t.ghostCell = findRegion(t.name + "-cell-ghost");

        // авто-генерируемая обводка корпуса - отдельный регион, спрайта для неё нет,
        // прячем через прозрачную заглушку
        t.normalOutline = t.type.outlineRegion;

        // сопла двигателей - НЕ спрайт, рисуются процедурно через цвет.
        // engineColor может быть null по умолчанию (тогда движок берёт цвет команды),
        // поэтому запоминаем именно исходный объект (в т.ч. null), а не альфу.
        t.normalEngineColor = t.type.engineColor;
        t.normalEngineInnerAlpha = t.type.engineColorInner.a;

        // оружие (если есть именной спрайт)
        if (t.hasWeaponSprite) {
            t.ghostWeapon = findRegion(t.name + "-weapon-ghost");
            t.normalWeapons = [];
            t.normalWeaponOutlines = [];
            t.type.weapons.each(function(w) {
                t.normalWeapons.push(w.region);
                t.normalWeaponOutlines.push(w.outlineRegion);
            });
        }
    }

    blankRegion = findRegion("transparent-units-blank");
});

Events.run(Trigger.update, function() {
    if (Core.input.keyTap(KeyCode.f9)) {
        visible = !visible;

        for (var i = 0; i < targets.length; i++) {
            var t = targets[i];

            if (t.ghostRegion != null) {
                t.type.region = visible ? t.normalRegion : t.ghostRegion;
            }
            if (t.ghostCell != null) {
                t.type.cellRegion = visible ? t.normalCell : t.ghostCell;
            }
            if (blankRegion != null) {
                t.type.outlineRegion = visible ? t.normalOutline : blankRegion;
            }

            // сопла: engineColor может быть null (тогда используется цвет команды),
            // поэтому при скрытии подставляем новый прозрачный Color,
            // а при показе возвращаем как было (в т.ч. обратно в null).
            t.type.engineColor = visible ? t.normalEngineColor : new Color(0, 0, 0, 0);
            t.type.engineColorInner.a = visible ? t.normalEngineInnerAlpha : 0;

            if (t.hasWeaponSprite && t.ghostWeapon != null) {
                var idx = 0;
                t.type.weapons.each(function(w) {
                    w.region = visible ? t.normalWeapons[idx] : t.ghostWeapon;
                    if (blankRegion != null) {
                        w.outlineRegion = visible ? t.normalWeaponOutlines[idx] : blankRegion;
                    }
                    idx++;
                });
            }
        }

        Vars.ui.hudfrag.showToast(visible ? "Юниты: видимы" : "Юниты: прозрачны");
    }
});
EOF

echo ""
echo "Готово! Мод собран в: $MOD_DIR"
echo ""
echo "Содержимое sprites-override/units/:"
ls -1 "$MOD_DIR/sprites-override/units/" 2>/dev/null || true
echo ""
echo "Дальше:"
echo "  1. Заархивируй содержимое папки '$MOD_DIR' в .zip"
echo "     (или просто скопируй саму папку в каталог mods/ игры)"
echo "  2. Mindustry -> Меню -> Модификации -> Импортировать модификацию"
echo "  3. В игре нажми F9, чтобы переключить видимость юнитов mono/poly/mega/quad/oct"
echo ""
echo "Замечания:"
echo "  - Подмена работает через общий 'region'/'cellRegion' типа юнита,"
echo "    поэтому эффект применяется ко всем юнитам этого типа (и своим, и вражеским)."
echo "  - Сопла (engineColor) прозрачны у ВСЕХ 5 юнитов - это не спрайт, а цвет,"
echo "    поэтому их не нужно было качать отдельно."
echo "  - Именной спрайт оружия со стволом есть только у poly и mega"
echo "    (mega использует один файл heal-weapon-mount.png на обе пушки)."
echo "  - У mono оружия нет вообще. У quad оружие рисуется без спрайта"
echo "    (только эффект бомбы). У oct оружия нет вообще (только щит и"
echo "    лечащее поле - это способности, не спрайты, их отдельно не спрятать)."
