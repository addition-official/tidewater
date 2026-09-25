// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Start button and start menu.
// The Meta key opens it (metadata: X-Plasma-Provides launchermenu).
// All system access goes through ../code/menu.py.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"
import "shared"

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

    Exec {
        id: exec
        onFinished: (cmd, out, code) => {
            if (!cmd.startsWith(root.base)) return;
            const rest = cmd.substring(root.base.length);
            let data = null;
            try { data = JSON.parse(out); } catch (e) { return; }
            if (rest === "apps") root.apps = data;
            else if (rest === "recent") root.recent = data;
            else if (rest === "stats") root.stats = data;
            else if (rest === "media") root.media = data;
            else if (rest === "taskbar-pins") root.taskbarPins = data;
            else if (rest.startsWith("files ")) {
                // tag results with the query they were for, not whatever is typed now
                const q = root.filesQuery[cmd];
                delete root.filesQuery[cmd];
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
    Component.onDestruction: Launchers.remove(root)
    onExpandedChanged: {
        if (!expanded) return;
        if (onScreen()) {
            // Just after Plasma (re)starts the panel may still be moving into
            // place, and a popup placed now can land in the corner: open it
            // again a moment later, once the panel has settled.
            const early = 1500 - (Date.now() - shownAt);
            if (early > 0 && !settled) {
                expanded = false;
                settleOpen.interval = early;
                settleOpen.restart();
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
    Component.onCompleted: { Launchers.add(root); py("apps"); py("stats"); }
    Timer {
        interval: 2000
        running: root.expanded
        repeat: true
        onTriggered: { root.py("stats"); root.py("media"); }
    }

    // ---- actions --------------------------------------------------------------
    function close() { root.expanded = false; }
    function launch(id) { py("launch " + exec.q(id)); close(); }
    // one of the app's own actions, e.g. a browser's "New private window"
    function launchAction(id, action) { py("action " + exec.q(id) + " " + exec.q(action)); close(); }
    function openUrl(url) { py("open " + exec.q(url)); close(); }
    function session(what) { close(); py("session " + exec.q(what)); }
    function mediaCmd(m) { py("media-cmd " + m); mediaSettle.restart(); }
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
            // closed: grey pill with a blue icon, hover like the Search pill; open: solid blue
            accent: root.expanded
            accentGlyph: true
            filled: true
            active: root.expanded
            size: Math.max(24, Math.round(46 * design.unit))
            glyph: "blur_on"
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
