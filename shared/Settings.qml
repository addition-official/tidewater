// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Tidewater's settings, shared by every Tidewater widget in this Plasma session.
//
// install.sh puts this file in ~/.local/share/tidewater/qml, and every widget
// imports it by the same relative path from its own folder. Plasma loads all
// widgets into one QML engine, so they all see this one object.
//
// Where the settings are stored: in the start widget's own configuration (the
// start widget is the "owner"). Each start widget hands its saved settings in
// here with offer(), and writes newer ones back into its own configuration, so
// with two monitors (two start widgets) they all end up the same. Without a
// start widget, the taskbar and clock keep the settings they had before (see
// offerLegacy); everything else stays at the defaults below.
//
// Every default reproduces Tidewater's look from before these options existed,
// except showAllDesktops (each desktop now shows only its own windows),
// showDesktopCorner (the "show desktop" strip is new, and off unless chosen),
// and workspaces and showDividers: like Windows, no desktop pills and no
// dividers unless chosen. (Settings saved before keep what they had.)
pragma Singleton
import QtQuick

QtObject {
    id: s

    // ---- the options (names are the start widget's config keys) -------------
    // Start button: "" = the built-in glyph; otherwise an icon theme name, or
    // the full path (or file:// address) of an image file.
    property string startIcon: ""
    property string searchStyle: "full"      // full (icon and "Search"), bar (a search box, like Windows), icon, hidden
    property bool showOverview: true
    property string workspaces: "hidden"     // numbers, dots, hidden
    property bool showDividers: false
    property bool showPower: true
    property bool showDesktopCorner: false   // thin "show desktop" strip at the far right
    property bool showBell: false            // separate notification bell (they are in the clock)
    // start menu
    property bool showNowPlaying: true
    property bool showMenuPower: true
    // taskbar
    property string alignment: "center"      // center, left
    property int iconSize: 28
    property bool expand: true               // fill the bar (so icons can be centered on the screen)
    property bool showAllDesktops: false     // false: each desktop shows only its own windows
    // clock
    property bool showSeconds: true
    property bool showDate: true
    property string hourMode: "system"       // system, 24h, 12h
    property string dateFormat: "ddd d MMM"
    // volume popup (Windows style)
    property bool volumePopup: true
    property bool volumeNumber: false

    // When the settings shown here were saved (milliseconds since 1970).
    // 0: nothing has been offered yet.
    property real rev: 0

    readonly property var defaults: ({
            startIcon: "",
            searchStyle: "full",
            showOverview: true,
            workspaces: "hidden",
            showDividers: false,
            showPower: true,
            showDesktopCorner: false,
            showBell: false,
            showNowPlaying: true,
            showMenuPower: true,
            alignment: "center",
            iconSize: 28,
            expand: true,
            showAllDesktops: false,
            showSeconds: true,
            showDate: true,
            hourMode: "system",
            dateFormat: "ddd d MMM",
            volumePopup: true,
            volumeNumber: false
        })
    readonly property var keys: Object.keys(defaults)
    // the options that used to live in the taskbar's and the clock's own settings
    readonly property var legacyKeys: ({
            tasks: ["alignment", "iconSize", "expand", "showAllDesktops"],
            clock: ["showSeconds", "showDate", "hourMode", "dateFormat"]
        })

    // A value as the option expects it; anything unusable gives the default.
    function clean(key, v) {
        const d = defaults[key];
        if (v === undefined || v === null)
            return d;
        if (typeof d === "boolean")
            return typeof v === "string" ? v === "true" : !!v;
        if (typeof d === "number") {
            const n = Math.round(Number(v));
            return isFinite(n) && n >= 12 && n <= 64 ? n : d;
        }
        const t = String(v);
        if (key === "searchStyle")
            return ["full", "bar", "icon", "hidden"].indexOf(t) >= 0 ? t : d;
        if (key === "workspaces")
            return ["numbers", "dots", "hidden"].indexOf(t) >= 0 ? t : d;
        if (key === "alignment")
            return t === "left" ? "left" : "center";
        if (key === "hourMode")
            return ["system", "24h", "12h"].indexOf(t) >= 0 ? t : d;
        if (key === "dateFormat")
            return t || d;
        return t;
    }

    // All options as one plain object.
    function values() {
        const out = {};
        for (const k of keys)
            out[k] = s[k];
        return out;
    }

    // A start widget hands in its saved settings. Taken only if they are at
    // least as new as what is here (equal is fine: it is the same save).
    // Returns whether they were taken.
    function offer(vals, when) {
        const r = Number(when) || 0;
        if (r < rev)
            return false;
        for (const k of keys)
            if (vals[k] !== undefined) {
                const v = clean(k, vals[k]);
                if (s[k] !== v)
                    s[k] = v;
            }
        // last, so whoever watches rev sees every new value already in place
        if (rev !== r)
            rev = r;
        return true;
    }

    // ---- the start icon ---------------------------------------------------------
    // A picture file rather than an icon theme name? (Theme names have no "/".)
    function isFile(src) {
        return String(src || "").indexOf("/") >= 0;
    }
    // What to give Kirigami.Icon: a theme name as it is, a full path as a
    // file:// address (each part encoded, so spaces, "#" and "?" are safe).
    function iconSource(src) {
        const t = String(src || "").trim();
        if (!t.startsWith("/"))
            return t;
        return "file://" + t.split("/").map(encodeURIComponent).join("/");
    }

    // ---- moving old settings over (one time) -----------------------------------
    // Before this file existed, the clock and the taskbar kept their options in
    // their own settings. They hand them in here when they start; a start
    // widget that has never saved settings takes them over (see start main.qml).
    property var legacy: ({})       // { tasks: {...}, clock: {...} }
    function offerLegacy(kind, vals) {
        if (legacy[kind])
            return;     // the first one wins (e.g. with a taskbar on each monitor)
        const l = Object.assign({}, legacy);
        l[kind] = vals;
        legacy = l;
        // Nothing saved by a start widget yet (or there is none, e.g. Plasma's
        // own menu instead of Tidewater's start button): use the old settings
        // straight away, without a rev, so a start widget's saved settings or
        // its migration still win when it loads.
        if (rev === 0)
            for (const k in vals)
                if (k in defaults)
                    s[k] = clean(k, vals[k]);
    }

    // ---- the volume popup ------------------------------------------------------
    // Shown by one quick settings widget only (with two monitors there are two
    // of them): the one on the main monitor, or else the first one. Worked out
    // again whenever a widget's monitor changes, so monitors going off and on
    // (e.g. during sleep) can never leave it with no widget.
    property var statusWidgets: []
    function addStatus(o) {
        if (statusWidgets.indexOf(o) < 0)
            statusWidgets = statusWidgets.concat([o]);
    }
    function removeStatus(o) {
        statusWidgets = statusWidgets.filter(x => x !== o);
    }
    readonly property var volumeHost: {
        for (const w of statusWidgets)
            if (w.onMainScreen)
                return w;
        return statusWidgets.length > 0 ? statusWidgets[0] : null;
    }

    // ---- opening the settings page --------------------------------------------
    // The settings page belongs to the start widget, so other widgets ask a
    // start widget to open its Configure dialog.
    property var owners: []
    readonly property bool canOpen: owners.length > 0
    function addOwner(o) {
        if (owners.indexOf(o) < 0)
            owners = owners.concat([o]);
    }
    function removeOwner(o) {
        owners = owners.filter(x => x !== o);
    }
    function openSettings() {
        // prefer a start button that is on screen, so the dialog opens there
        let pick = null;
        for (const o of owners)
            if (!pick || (o.onScreen && o.onScreen()))
                pick = o;
        if (pick)
            pick.openSettingsPage();
    }

    // ---- search ----------------------------------------------------------------
    // The taskbar's search box or button opens the start menu ready to type in,
    // like Windows: the start button on the same monitor if there is one, else
    // any start button on screen. False when there is no start button.
    function openStartSearch(screen) {
        const pick = searchOwner(screen);
        if (!pick)
            return false;
        pick.openSearch();
        return true;
    }
    // The start widget whose search (apps, files, actions) and launcher the
    // taskbar's search box uses: the one on the same monitor if there is one.
    // A taskbar search box started typing: the others (other monitors) stop.
    signal searchStarted(var box)

    function searchOwner(screen) {
        let pick = null;
        for (const o of owners) {
            if (o.screenIndex === screen && o.onScreen && o.onScreen())
                return o;
            if (!pick || (o.onScreen && o.onScreen()))
                pick = o;
        }
        return pick;
    }
}
