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
