// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Plasma desktop script: builds the panel from the Tidewater widgets, in the
// Tidewater arrangement. install.sh fills in:
//   __STYLE__    full (default), floating, or islands
//   __SCREENS__  primary or all
var STYLE = "__STYLE__";
var SCREENS = "__SCREENS__";
var P = "tidewater";

// Out with the old panels (install.sh has already backed them up), but only on
// the screens we are about to build on: other monitors keep their panels.
panels().forEach(function (p) {
    if (SCREENS === "all" || p.screen === 0) p.remove();
});

// Plasma puts a script-made panel on whichever monitor KWin calls "active"
// (where the mouse is), so pin each one explicitly. Screen 0 is the primary.
var targetScreen = 0;

function makePanel(align, fit) {
    var p = new Panel;
    p.screen = targetScreen;
    p.location = "bottom";
    p.height = 52;                        // bar thickness
    p.floating = STYLE !== "full";
    p.hiding = "none";
    p.lengthMode = fit ? "fit" : "fill";
    p.alignment = align;
    return p;
}

// KEEP (added by install.sh) holds settings carried over from the old panel:
// { "<plugin id>": { "<key>": "<value>" or ["list", "items"] } }
// Lists (pinned apps) must stay arrays: a comma-joined string would be stored
// as a single item.
if (typeof KEEP === "undefined") var KEEP = {};

function add(panel, plugin) {
    var w = panel.addWidget(plugin);
    if (!w) {
        print("tidewater: Plasma couldn't find the widget " + plugin);
        return null;
    }
    var saved = KEEP[plugin];
    if (w && saved) {
        w.currentConfigGroup = ["General"];
        for (var k in saved) w.writeConfig(k, saved[k]);
    }
    return w;
}

function spacer(panel) {
    var w = add(panel, "org.kde.plasma.panelspacer");
    if (!w) return;
    w.currentConfigGroup = ["General"];
    w.writeConfig("expanding", true);
}

function left(panel) {
    add(panel, P + ".start");
    add(panel, P + ".search");
    add(panel, P + ".taskview");
    add(panel, P + ".divider");
    add(panel, P + ".workspaces");
}

function middle(panel, expand) {
    var t = add(panel, P + ".tasks");
    if (!t) return;
    t.currentConfigGroup = ["General"];
    t.writeConfig("expand", expand);   // fills the bar, so icons can sit left or centre
}

function right(panel) {
    // tidy-tray.sh takes Plasma's own network/volume/Bluetooth/bell icons
    // out of this tray afterwards.
    add(panel, "org.kde.plasma.systemtray");
    add(panel, P + ".divider");
    add(panel, P + ".status");             // network / bluetooth / volume + quick settings
    add(panel, P + ".clock");
    add(panel, P + ".notifications");
    add(panel, P + ".power");
}

function build() {
    if (STYLE === "islands") {
        var l = makePanel("left", true);   left(l);
        var m = makePanel("center", true); middle(m, false);
        var r = makePanel("right", true);  right(r);
    } else {
        var bar = makePanel("center", false);
        left(bar);
        middle(bar, true);
        right(bar);
    }
}

var count = SCREENS === "all" ? screenCount : 1;
for (var s = 0; s < count; s++) {
    targetScreen = s;
    build();
}
