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
    property var settingsPages: []    // System Settings pages, for search
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
            else if (rest === "settings") root.settingsPages = data;
            else if (rest === "recent") root.recent = root.withoutHidden(data);
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
    // Always root.expanded here: the signal also hands in a value named
    // "expanded", and leaning on that is deprecated in Qt 6 (and assigning to
    // it would only change that copy, not close the popup).
    onExpandedChanged: {
        if (!root.expanded) { menuClosed(); return; }
        if (onScreen()) {
            // Just after Plasma (re)starts the panel may still be moving into
            // place, and a popup placed now can land in the corner: open it
            // again a moment later, once the panel has settled.
            const early = 1500 - (Date.now() - shownAt);
            if (early > 0 && !settled) {
                root.expanded = false;
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
            rememberFocus();
            refreshAll();
            return;
        }
        // Opened (by the Meta key) on a copy with no visible button: Plasma
        // would put the popup at the top-left. Open the on-screen copy instead.
        const other = Launchers.onScreenOne(root);
        if (other) {
            root.expanded = false;
            other.expanded = true;
        } else {
            rememberFocus();
            refreshAll();                // no better copy: open this one as usual
        }
    }

    function refreshAll() { py("apps"); py("recent"); py("stats"); if (Settings.showNowPlaying) py("media"); py("taskbar-pins"); }
    Component.onCompleted: {
        Launchers.add(root);
        py("apps");
        py("settings");
        py("stats");
        startSettings();
    }
    // what's playing, kept current while the menu is open
    Timer {
        interval: 2000
        running: root.expanded && Settings.showNowPlaying
        repeat: true
        onTriggered: root.py("media")
    }

    // ---- actions --------------------------------------------------------------
    function close() { root.expanded = false; }
    // The new design's "View:" menu (category, grid, list): kept like any
    // other Tidewater setting (see "Tidewater settings" below)
    function setStartView(v) {
        if (Plasmoid.configuration.startView === v) return;
        Plasmoid.configuration.startView = v;
        Plasmoid.configuration.settingsRev = String(Date.now());
    }
    // Opening something hands the keyboard on to it: no going back (below).
    function launch(id) { handingOff = true; pyNow("launch " + exec.q(id)); close(); }
    // one of the app's own actions, e.g. a browser's "New private window"
    function launchAction(id, action) { handingOff = true; pyNow("action " + exec.q(id) + " " + exec.q(action)); close(); }
    function openUrl(url) { handingOff = true; pyNow("open " + exec.q(url)); close(); }
    function session(what) { handingOff = true; close(); pyNow("session " + exec.q(what)); }

    // ---- the window you were in, back when the menu closes (FocusReturn.qml) --
    FocusReturn { id: focusReturn }
    property alias handingOff: focusReturn.handingOff
    function rememberFocus() { focusReturn.remember(); }
    function menuClosed() {
        // the menu still had the keyboard: closed by Escape, the Start button
        // or the Meta key, not by a click on another window or the desktop
        const full = root.fullRepresentationItem;
        focusReturn.closed(!!full && !!full.Window.window && full.Window.window.active);
    }
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
    // Saved as a list of entries (Plasmoid.configuration.pinned): an app's id,
    // or an app folder, "folder:<name>:<id>|<id>|...", name URI-encoded.
    readonly property var pinnedIds: Plasmoid.configuration.pinned
    readonly property var appsById: {
        const byId = {};
        for (const a of apps) byId[a.id] = a;
        return byId;
    }
    function isFolderEntry(e) { return String(e).startsWith("folder:"); }
    function parseFolder(e) {
        const rest = String(e).substring(7);
        const at = rest.indexOf(":");
        let name = "Folder";
        try { name = decodeURIComponent(rest.substring(0, at)) || "Folder"; } catch (err) {}
        return { name: name, ids: rest.substring(at + 1).split("|").filter(x => x.length > 0) };
    }
    function folderEntry(name, ids) { return "folder:" + encodeURIComponent(name || "Folder") + ":" + ids.join("|"); }
    // What Pinned shows (the new design): apps and folders, in order. Apps
    // that are not installed (any more) are left out; so is a folder with none.
    readonly property var pinnedItems: {
        const out = [];
        const seen = {};
        for (const e of pinnedIds) {
            if (isFolderEntry(e)) {
                const f = parseFolder(e);
                const fa = f.ids.map(id => appsById[id]).filter(a => !!a);
                if (fa.length > 0) out.push({ kind: "folder", key: e, name: f.name, apps: fa });
            } else {
                const a = appsById[e];
                if (a && !seen[a.name]) { seen[a.name] = true; out.push(a); }
            }
        }
        return out;
    }
    // Every pinned app, folders opened up (search, the classic design, menus)
    readonly property var pinnedApps: {
        const out = [];
        for (const it of pinnedItems) {
            if (it.kind === "folder") for (const a of it.apps) out.push(a);
            else out.push(it);
        }
        return out;
    }
    function keyOf(item) { return item.kind === "folder" ? item.key : item.id; }
    function isPinned(id) { return pinnedApps.some(a => a.id === id); }
    function isOnTaskbar(id) { return taskbarPins.indexOf(id) >= 0; }
    function toggleTaskbar(id) {
        const pin = !isOnTaskbar(id);
        // show it straight away; the helper confirms a moment later
        taskbarPins = pin ? taskbarPins.concat([id]) : taskbarPins.filter(x => x !== id);
        py((pin ? "taskbar-pin " : "taskbar-unpin ") + exec.q(id));
        pinsSettle.restart();
    }
    Timer { id: pinsSettle; interval: 700; onTriggered: root.py("taskbar-pins") }

    // The saved list without `id` anywhere (top level or in a folder);
    // a folder left empty goes.
    function withoutApp(list, id) {
        const out = [];
        for (const e of list) {
            if (isFolderEntry(e)) {
                const f = parseFolder(e);
                const ids = f.ids.filter(x => x !== id);
                if (ids.length > 0) out.push(ids.length === f.ids.length ? e : folderEntry(f.name, ids));
            } else if (e !== id) {
                out.push(e);
            }
        }
        return out;
    }
    function savePins(list) { Plasmoid.configuration.pinned = list; }
    function togglePin(id) {
        if (isPinned(id)) savePins(withoutApp(pinnedIds, id));
        else savePins(pinnedIds.concat([id]));
    }
    // The shown position of an app (by id) or a folder (by its entry)
    function pinIndex(key) { return pinnedItems.findIndex(it => keyOf(it) === key); }
    // A pinned app or folder to position `to` among what Pinned shows;
    // entries for apps not installed keep their place at the end.
    function movePinTo(key, to) {
        const shown = pinnedItems.map(keyOf);
        const i = shown.indexOf(key);
        if (i < 0) return;
        to = Math.max(0, Math.min(shown.length - 1, to));
        if (to === i) return;
        shown.splice(i, 1);
        shown.splice(to, 0, key);
        savePins(shown.concat(pinnedIds.filter(x => shown.indexOf(x) < 0)));
    }
    // "Move to front / left / right", like Windows: `where` is "front", -1 or 1.
    function movePin(key, where) {
        const i = pinIndex(key);
        if (i < 0) return;
        movePinTo(key, where === "front" ? 0 : i + where);
    }

    // ---- app folders, like Windows 11 ----------------------------------------
    // "Create a new app folder": the app becomes a folder named "Folder"
    // holding it, in its place.
    function createFolder(id) {
        savePins(pinnedIds.map(e => e === id ? folderEntry("Folder", [id]) : e));
    }
    function renameFolder(key, name) {
        name = String(name || "").trim() || "Folder";
        savePins(pinnedIds.map(e => e === key ? folderEntry(name, parseFolder(e).ids) : e));
    }
    // "Remove from app folder": the app goes back into Pinned right after the
    // folder (the folder's place, if it was the last one in it).
    function removeFromFolder(key, id) {
        const out = [];
        for (const e of pinnedIds) {
            if (e === key) {
                const f = parseFolder(e);
                const ids = f.ids.filter(x => x !== id);
                if (ids.length > 0) out.push(folderEntry(f.name, ids));
                out.push(id);
            } else {
                out.push(e);
            }
        }
        savePins(out);
    }
    // Dragging: an app dropped on a folder joins it; on another app, the two
    // become a new folder in the target's place.
    function addToFolder(key, id) {
        const f = parseFolder(key);
        if (f.ids.indexOf(id) >= 0) return;
        // out of wherever it was (this folder's entry stays as it is: the app
        // is not in it), then into the folder
        savePins(withoutApp(pinnedIds, id).map(e => e === key ? folderEntry(f.name, f.ids.concat([id])) : e));
    }
    function makeFolder(targetId, id) {
        if (targetId === id) return;
        const list = withoutApp(pinnedIds, id);
        savePins(list.map(e => e === targetId ? folderEntry("Folder", [targetId, id]) : e));
    }

    // ---- recent files: "Remove from list" and "Open file location" -----------
    // Removed files are only taken off the start menu (Tidewater's own list,
    // "hiddenRecent"); the system's list of recent files, which other apps
    // use too, stays as it is.
    readonly property var hiddenRecent: Plasmoid.configuration.hiddenRecent || []
    function withoutHidden(list) { return (list || []).filter(f => hiddenRecent.indexOf(f.url) < 0); }
    function hideRecent(url) {
        if (!url || hiddenRecent.indexOf(url) >= 0) return;
        // the newest 200 are plenty
        Plasmoid.configuration.hiddenRecent = hiddenRecent.concat([url]).slice(-200);
        recent = withoutHidden(recent);
    }
    // the file's folder, with the file selected (as KDE's apps do it)
    function revealFile(url) { handingOff = true; pyNow("reveal " + exec.q(url)); close(); }


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
        // System Settings pages, by name first, then by keywords and description
        const pages = [];
        for (const p of settingsPages) {
            const n = p.name.toLowerCase();
            const s = n.startsWith(ql) ? 3 : n.indexOf(ql) >= 0 ? 2
                    : ((p.keywords || "") + " " + (p.comment || "")).toLowerCase().indexOf(ql) >= 0 ? 1 : 0;
            if (s > 0) pages.push({ s: s, p: p });
        }
        pages.sort((x, y) => y.s - x.s || x.p.name.localeCompare(y.p.name));
        for (const x of pages.slice(0, 4))
            out.push({ kind: "setting", id: x.p.id, name: x.p.name, icon: x.p.icon, description: x.p.comment || "System Settings" });
        if (files && files.q === q)
            for (const f of files.items.slice(0, 5))
                out.push({ kind: "file", url: f.url, name: f.name, folder: f.folder, icon: f.icon,
                           glyph: f.folder ? "folder_open" : "description", description: f.dir });
        for (const a of actions)
            if (a.name.toLowerCase().indexOf(ql) >= 0) out.push(act(a));
        return out;
    }

    // ---- formatting -------------------------------------------------------------
    // "Downloads · 2 h ago" for a recent file: the folder it is in (Home for
    // your home folder) and when it was last used.
    function fileWhere(f) {
        const dir = String(f.dir || "");
        const folder = dir === "~" ? "Home" : (dir.split("/").filter(p => p.length > 0).pop() || dir);
        const when = ago(f.when);
        return when ? folder + " · " + when : folder;
    }
    function ago(iso) {
        const t = Date.parse(iso || "");
        if (!(t > 0)) return "";
        const min = Math.floor((Date.now() - t) / 60000);
        if (min < 1) return "Just now";
        if (min < 60) return min + " min ago";
        const d = new Date(t), now = new Date();
        const days = Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate())
                                 - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        if (days === 0) return Math.floor(min / 60) + " h ago";
        if (days === 1) return "Yesterday";
        if (days < 7) return Qt.formatDate(d, "dddd");
        return Qt.formatDate(d, now.getFullYear() === d.getFullYear() ? "MMM d" : "MMM d, yyyy");
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

    // The taskbar's search box comes here (see Settings.openStartSearch): open
    // the menu, which puts the cursor in its search field (StartMenu.reset).
    readonly property int screenIndex: Plasmoid.containment ? Plasmoid.containment.screen : -1
    function openSearch() { root.expanded = true; }
    // The search, narrowed to one of the search panel's tabs
    // (all, apps, documents, folders, settings).
    function searchIn(query, tab) {
        if (query.trim().length === 0) return [];
        const keep = tab === "apps" ? (r => r.kind === "app")
                   : tab === "documents" ? (r => r.kind === "file" && !r.folder)
                   : tab === "folders" ? (r => r.kind === "file" && r.folder)
                   : tab === "settings" ? (r => r.kind === "setting")
                   : (r => true);
        return search(query, fileResults).filter(keep);
    }

    // Other widgets' "Tidewater settings..." comes here (see Settings.openSettings).
    function openSettingsPage() { Plasmoid.internalAction("configure").trigger(); }

    // ---- in the panel -------------------------------------------------------------
    compactRepresentation: Item {
        NoOpenLine {}   // no Plasma "open" line over the panel (common/NoOpenLine.qml)
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
        // A fixed size: Plasma remembers a popup's last size, and would
        // otherwise keep showing it at an older, bigger one. Wider while
        // searching, like Windows, where the search view is wider than Start.
        // (and the new design is bigger than the classic one)
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight
        Connections {
            target: root
            // fresh each time it opens; and cleared as it closes, so it never
            // opens showing (and sized for) the last search
            function onExpandedChanged() { startMenu.reset(); }
        }
    }
}
