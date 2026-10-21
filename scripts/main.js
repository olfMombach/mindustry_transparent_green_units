// Units in the green (construction/support) aerial branch.
// hasWeaponSprite=true -> the unit has a dedicated weapon file that includes a barrel (poly, mega).
var targets = [
    { type: UnitTypes.mono, name: "mono", hasWeaponSprite: false },
    { type: UnitTypes.poly, name: "poly", hasWeaponSprite: true },
    { type: UnitTypes.mega, name: "mega", hasWeaponSprite: true },
    { type: UnitTypes.quad, name: "quad", hasWeaponSprite: false },
    { type: UnitTypes.oct,  name: "oct",  hasWeaponSprite: false }
];

var visible = true; // true = standard sprites, false = transparent
var blankRegion = null; // transparent placeholder for auto-outlines

function findRegion(name) {
    var r = Core.atlas.find(name);
    if (r == null) {
        Log.warn("[transparent-units] sprite not found: " + name);
    }
    return r;
}

Events.on(ClientLoadEvent, function(e) {
    for (var i = 0; i < targets.length; i++) {
        var t = targets[i];

        // main body
        t.normalRegion = t.type.region;
        t.ghostRegion = findRegion(t.name + "-ghost");

        // "cell"/cabin
        t.normalCell = t.type.cellRegion;
        t.ghostCell = findRegion(t.name + "-cell-ghost");

        // Auto-generated hull outline - a separate region; there is no sprite for it,
        // so we hide it using a transparent placeholder.
        t.normalOutline = t.type.outlineRegion;

        // Engine nozzles are NOT sprites; they are rendered procedurally using color.
        // `engineColor` can be `null` by default (in which case the engine uses the team color),
        // so we store the original object itself (including `null`) rather than just the alpha value.
        t.normalEngineColor = t.type.engineColor;
        t.normalEngineInnerAlpha = t.type.engineColorInner.a;

        // Weapons (if a specific sprite is defined)
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

            // Thrusters: `engineColor` can be `null` (in which case the team color is used);
            // therefore, when hiding, we substitute a new transparent `Color`,
            // and when showing, we restore the original value (including setting it back to `null` if applicable).
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

        Vars.ui.hudfrag.showToast(visible ? "Units: visible" : "Units: transparent");
    }
});
