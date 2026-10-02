// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Start button and start menu.
// The Meta key opens it (metadata: X-Plasma-Provides launchermenu).
// All system access goes through ../code/menu.py.
// It also keeps Tidewater's settings for every other Tidewater widget: see
// "Tidewater settings" below, and shared/Settings.qml.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"
import "shared"
// ~/.local/share/tidewater/qml (install.sh puts it there): the same folder
// for every widget, so they all share one Settings object.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Start"
    Palette { id: design }

    // ---- data -------------------------------------------------------------------
    property var apps: []
    property var recent: []
    property var stats: ({})
    property var media: ({})
    property var fileResults: ({ q: "", items: [] })
    property var taskbarPins: []

    readonly property string helper: {
        const u = Qt.resolvedUrl("../code/menu.py").toString();
        return u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
    }
    readonly property string base: "python3 " + exec.q(helper) + " "
    function py(args) { exec.run(base + args); }
    // for things the user asked for: never skipped, even if the same one still runs
    function pyNow(args) { exec.start(base + args); }

    Exec {
        id: exec
        onFinished: (cmd, out, code) => {
            if (!cmd.startsWith(root.base)) return;
            const rest = cmd.substring(root.base.length);
            // the query this files search was for (dropped even if the output is bad)
            const q = root.filesQuery[cmd];
            delete root.filesQuery[cmd];
            let data = null;
            try { data = JSON.parse(out); } catch (e) { return; }
            if (rest === "apps") root.apps = data;
            else if (rest === "recent") root.recent = data;
            else if (rest === "stats") root.stats = data;
            else if (rest === "media") root.media = data;
            else if (rest === "taskbar-pins") root.taskbarPins = data;
            else if (rest.startsWith("files ")) {
                // tag results with the query they were for, not whatever is typed now
                if (q !== undefined) root.fileResults = { q: q, items: data };
            }
        }
    }

    // ---- never pop up in the corner ------------------------------------------
    property Item button: null          // set by the panel button below
    function onScreen() { return !!(button && button.shown); }
    property double shownAt: 0          // when the panel button last appeared
    property bool settled: false        // set when the deferred open fires
    Timer { id: settleOpen; onTriggered: { root.settled = true; root.expanded = true; } }
    Component.onDestruction: {
        Launchers.remove(root);
        Settings.removeOwner(root);
    }
    onExpandedChanged: {
        if (!expanded) return;
        if (onScreen()) {
            // Just after Plasma (re)starts the panel may still be moving into
            // place, and a popup placed now can land in the corner: open it
            // again a moment later, once the panel has settled.
            const early = 1500 - (Date.now() - shownAt);
            if (early > 0 && !settled) {
                expanded = false;
                // asked again while waiting: that is a second click, so close
                if (settleOpen.running) {
                    settleOpen.stop();
                } else {
                    settleOpen.interval = early;
                    settleOpen.start();
                }
                return;
            }
            settled = false;
            refreshAll();
            return;
        }
        // Opened (by the Meta key) on a copy with no visible button: Plasma
        // would put the popup at the top-left. Open the on-screen copy instead.
        const other = Launchers.onScreenOne(root);
        if (other) {
            expanded = false;
            other.expanded = true;
        } else {
            refreshAll();                // no better copy: open this one as usual
        }
    }

    function refreshAll() { py("apps"); py("recent"); py("stats"); py("media"); py("taskbar-pins"); }
    Component.onCompleted: {
        Launchers.add(root);
        py("apps");
        py("stats");
        startSettings();
    }
    Timer {
        interval: 2000
        running: root.expanded
        repeat: true
        onTriggered: { root.py("stats"); root.py("media"); }
    }

    // ---- actions --------------------------------------------------------------
    function close() { root.expanded = false; }
    function launch(id) { pyNow("launch " + exec.q(id)); close(); }
    // one of the app's own actions, e.g. a browser's "New private window"
    function launchAction(id, action) { pyNow("action " + exec.q(id) + " " + exec.q(action)); close(); }
    function openUrl(url) { pyNow("open " + exec.q(url)); close(); }
    function session(what) { close(); pyNow("session " + exec.q(what)); }
    function mediaCmd(m) { pyNow("media-cmd " + exec.q(m)); mediaSettle.restart(); }
    Timer { id: mediaSettle; interval: 400; onTriggered: root.py("media") }

    property string pendingFiles: ""
    property var filesQuery: ({})     // command -> the query it searched for
    function searchFiles(q) {
        pendingFiles = q.trim();
        filesDebounce.restart();
    }
    Timer {
        id: filesDebounce
        interval: 250
        onTriggered: {
            if (root.pendingFiles.length > 1 && !root.pendingFiles.startsWith(">")) {
                const cmd = root.base + "files " + exec.q(root.pendingFiles);
                root.filesQuery[cmd] = root.pendingFiles;
                exec.run(cmd);
            } else {
                root.fileResults = { q: root.pendingFiles, items: [] };
            }
        }
    }

    // ---- pinned -----------------------------------------------------------------
    readonly property var pinnedIds: Plasmoid.configuration.pinned
    readonly property var pinnedApps: {
        const byId = {};
        for (const a of apps) byId[a.id] = a;
        const seen = {};
        const out = [];
        for (const id of pinnedIds) {
            const a = byId[id];
            if (a && !seen[a.name]) { seen[a.name] = true; out.push(a); }
        }
        return out;
    }
    function isPinned(id) { return pinnedIds.indexOf(id) >= 0; }
    function isOnTaskbar(id) { return taskbarPins.indexOf(id) >= 0; }
    function toggleTaskbar(id) {
        const pin = !isOnTaskbar(id);
        // show it straight away; the helper confirms a moment later
        taskbarPins = pin ? taskbarPins.concat([id]) : taskbarPins.filter(x => x !== id);
        py((pin ? "taskbar-pin " : "taskbar-unpin ") + exec.q(id));
        pinsSettle.restart();
    }
    Timer { id: pinsSettle; interval: 700; onTriggered: root.py("taskbar-pins") }
    function togglePin(id) {
        const list = pinnedIds.slice();
        const i = list.indexOf(id);
        if (i >= 0) list.splice(i, 1); else list.push(id);
        Plasmoid.configuration.pinned = list;
    }

    // ---- categories  -----------------------------
    function categoryOf(app) {
        const c = String(app.categories || "").split(/[;,]/).map(s => s.trim()).filter(s => s.length > 0);
        const has = k => c.indexOf(k) >= 0;
        if (has("Game")) return "games";
        if (has("Development") || has("IDE")) return "development";
        if (has("Network") || has("WebBrowser") || has("Email") || has("Chat") || has("InstantMessaging")) return "internet";
        if (has("AudioVideo") || has("Audio") || has("Video") || has("Graphics") || has("Photography")) return "multimedia";
        if (has("Settings") || has("System") || has("Monitor") || has("PackageManager")) return "system";
        return "utilities";
    }
    function inCategory(cat) { return apps.filter(a => categoryOf(a) === cat); }

    // ---- search -----------------------------------------------------------------
    readonly property var actions: [
        { id: "lock", name: "Lock screen", glyph: "lock" },
        { id: "sleep", name: "Sleep", glyph: "bedtime" },
        { id: "logout", name: "Log out", glyph: "logout" },
        { id: "restart", name: "Restart", glyph: "restart_alt" },
        { id: "shutdown", name: "Shut down", glyph: "power_settings_new" },
        { id: "settings", name: "System Settings", glyph: "settings" }
    ]
    function search(query, files) {
        const q = query.trim();
        if (!q) return [];
        const act = a => ({ kind: "action", id: a.id, name: a.name, glyph: a.glyph, description: "Action" });
        if (q.startsWith(">")) {
            const t = q.substring(1).trim().toLowerCase();
            return actions.filter(a => !t || a.name.toLowerCase().indexOf(t) >= 0).map(act);
        }
        const ql = q.toLowerCase();
        const scored = [];
        for (const a of apps) {
            const n = a.name.toLowerCase();
            let s = n.startsWith(ql) ? 4 : n.indexOf(ql) >= 0 ? 3
                  : (a.generic || "").toLowerCase().indexOf(ql) >= 0 ? 2
                  : ((a.keywords || "") + " " + (a.comment || "")).toLowerCase().indexOf(ql) >= 0 ? 1 : 0;
            if (s > 0) scored.push({ s: s, a: a });
        }
        scored.sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name));
        const out = scored.slice(0, 7).map(x => ({ kind: "app", id: x.a.id, name: x.a.name, icon: x.a.icon,
                                                   description: x.a.generic || x.a.comment || "" }));
        for (const a of actions)
            if (a.name.toLowerCase().indexOf(ql) >= 0) out.push(act(a));
        if (files && files.q === q)
            for (const f of files.items.slice(0, 5))
                out.push({ kind: "file", url: f.url, name: f.name, glyph: f.folder ? "folder_open" : "description",
                           description: f.dir });
        return out;
    }

    // ---- formatting -------------------------------------------------------------
    function bytes(n) {
        if (!(n > 0)) return "0 B";
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return (i >= 3 ? n.toFixed(n < 10 ? 1 : 0) : Math.round(n)) + " " + u[i];
    }
    function uptimeText(sec) {
        if (!sec) return "";
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return d > 0 ? "up " + d + " d " + h + " h" : "up " + h + " h " + (m < 10 ? "0" : "") + m + " min";
    }

    // ---- Tidewater settings ----------------------------------------------------
    // This widget's configuration is where Tidewater's settings are saved (the
    // settings page, ConfigGeneral.qml, is this widget's Configure dialog).
    // Saved settings go into the shared Settings object, and newer ones from
    // there (another start widget, e.g. on a second monitor) come back into
    // this widget's configuration, so every copy ends up the same.
    readonly property real savedRev: Number(Plasmoid.configuration.settingsRev) || 0
    // Every option as saved here: changes whenever one of them does.
    readonly property var saved: {
        const c = Plasmoid.configuration;
        const out = {};
        for (const k of Settings.keys)
            out[k] = c[k];
        return out;
    }
    // Set while this widget writes settings into its own configuration, so
    // those writes are not handed straight back (no ping-pong).
    property bool adopting: false
    onSavedChanged: if (!adopting) Qt.callLater(pushSettings)
    onSavedRevChanged: if (!adopting) Qt.callLater(pushSettings)

    function startSettings() {
        Settings.addOwner(root);
        pushSettings();
        // Never saved: move the taskbar's and clock's old settings over, once
        // they have handed them in (they start at about the same time), or
        // after a short wait if one of them isn't there.
        if (savedRev === 0 && Settings.rev === 0) {
            if (Settings.legacy.tasks && Settings.legacy.clock)
                migrateLegacy();
            else
                migrateWait.start();
        }
    }
    function pushSettings() {
        if (!Settings.offer(saved, savedRev) || Settings.rev > savedRev)
            adoptSettings();
    }
    // Newer settings arrived (from another start widget): save them here too.
    function adoptSettings() {
        if (Settings.rev <= savedRev)
            return;
        const v = Settings.values();
        adopting = true;
        for (const k of Settings.keys)
            if (Plasmoid.configuration[k] !== v[k])
                Plasmoid.configuration[k] = v[k];
        Plasmoid.configuration.settingsRev = String(Settings.rev);
        adopting = false;
    }
    Connections {
        target: Settings
        function onRevChanged() { root.adoptSettings(); }
        function onLegacyChanged() {
            if (migrateWait.running && Settings.legacy.tasks && Settings.legacy.clock) {
                migrateWait.stop();
                root.migrateLegacy();
            }
        }
    }

    // One time: the taskbar and the clock used to keep their options in their
    // own settings. Take those over, save them here, and share them.
    Timer {
        id: migrateWait
        interval: 2500
        onTriggered: root.migrateLegacy()
    }
    function migrateLegacy() {
        // another start widget may have done it (or had settings) meanwhile
        if (savedRev > 0 || Settings.rev > 0) {
            adoptSettings();
            return;
        }
        const v = Object.assign({}, saved);
        for (const kind in Settings.legacyKeys) {
            const old = Settings.legacy[kind];
            if (!old)
                continue;
            for (const k of Settings.legacyKeys[kind])
                if (old[k] !== undefined && old[k] !== null)
                    v[k] = old[k];
        }
        const when = Date.now();
        adopting = true;
        for (const k of Settings.keys) {
            v[k] = Settings.clean(k, v[k]);
            if (Plasmoid.configuration[k] !== v[k])
                Plasmoid.configuration[k] = v[k];
        }
        Plasmoid.configuration.settingsRev = String(when);
        adopting = false;
        Settings.offer(v, when);
    }

    // Other widgets' "Tidewater settings..." comes here (see Settings.openSettings).
    function openSettingsPage() { Plasmoid.internalAction("configure").trigger(); }

    // ---- in the panel -------------------------------------------------------------
    compactRepresentation: Item {
        Layout.minimumWidth: button.implicitWidth
        Layout.preferredWidth: button.implicitWidth
        Layout.maximumWidth: button.implicitWidth
        Layout.fillHeight: true
        BarButton {
            id: button
            Component.onCompleted: root.button = button
            // on a panel that is actually showing (read here: "Window" is per item)
            readonly property bool shown: visible && width > 0 && Window.window !== null && Window.window.visible
            onShownChanged: if (shown) root.shownAt = Date.now()
            anchors.centerIn: parent
            pal: design
            // closed: gray pill with a blue icon, hover like the Search pill; open: solid blue
            accent: root.expanded
            accentGlyph: true
            filled: true
            active: root.expanded
            size: Math.max(24, Math.round(46 * design.unit))
            // Settings: the built-in glyph, or an icon or picture of your own
            glyph: Settings.startIcon ? "" : "blur_on"
            image: Settings.iconSource(Settings.startIcon)
            // theme icons follow the button's colors; pictures are shown as they are
            imageTinted: !Settings.isFile(Settings.startIcon)
            fallback: "start-here-kde-symbolic"
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: StartMenu {
        id: startMenu
        app: root
        pal: design
        Layout.preferredWidth: 928
        Layout.preferredHeight: 668
        Layout.minimumWidth: 928
        Layout.minimumHeight: 668
        Connections {
            target: root
            function onExpandedChanged() { if (root.expanded) startMenu.reset(); }
        }
    }
}
