// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The start menu, in the manner of Windows 11, in two designs (Tidewater's
// settings, "startStyle"):
// - new (800 x 780), like Windows 11 today: one page that scrolls: Pinned
//   (two rows of eight, "Show all" for the rest), Recent (two rows of three,
//   "Show all" for every recent file), and All: every app, by category
//   (tiles of up to four icons; click one to open the app, or the tile for
//   the whole category), as a grid or as a list ("View:", kept as
//   "startView"). Checked against Windows 11 itself.
// - classic (640 x 700): pinned apps and recommended files, with All apps
//   (A to Z, with category filters) on a page of its own.
// Both: search on top; a slim now-playing card while something plays; your
// name and the power button at the bottom. Typing turns it into the same
// search panel as the taskbar's box (common/SearchPanel.qml), 820 wide, with
// this box on top, like Windows.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import "common"
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings, shared by every Tidewater widget.
import "../../../../../tidewater/qml"

Item {
    id: sm
    required property var app      // main.qml's root: data and actions
    required property var pal

    readonly property bool modern: Settings.startStyle !== "classic"
    implicitWidth: searching ? 820 : modern ? 800 : 640   // wider while searching, like Windows
    implicitHeight: modern ? 780 : 700

    // float a little away from the panel and the screen edges, like Windows 11
    FloatingPopup {}

    property string view: "home"   // home | all (classic) | recent
    property bool pinnedExpanded: false   // new design: "Show all" pinned apps
    property string openCategory: ""      // new design: the category shown in the panel
    property int openFolder: -1           // new design: the app folder shown (its place in Pinned)
    readonly property var openFolderItem: {
        const it = openFolder >= 0 ? (app.pinnedItems || [])[openFolder] : null;
        return it && it.kind === "folder" ? it : null;
    }
    readonly property bool panelOpen: openCategory !== "" || !!openFolderItem
    function closePanel() { openCategory = ""; openFolder = -1; }

    // ---- dragging in Pinned (new design), like Windows: drop between tiles
    // to move an app or folder there; drop an app on another app to make a
    // folder of the two, or on a folder to add it.
    property var dragging: null          // { key, kind, icon, folder } while dragging
    property point dragAt                // where the pointer is (in sm)
    property var dropHint: null          // { key, zone: "before" | "after" | "on" }
    property var pinTiles: []            // the pinned tiles on screen
    function registerTile(t) { pinTiles = pinTiles.concat([t]); }
    function unregisterTile(t) { pinTiles = pinTiles.filter(x => x !== t); }
    // the pinned tile under a point (in sm), and which part of it
    function pinnedAt(pt) {
        for (const t of pinTiles) {
            if (!t.visible || !t.pinKey) continue;
            const p = t.mapFromItem(sm, pt.x, pt.y);
            if (p.x < 0 || p.y < 0 || p.x >= t.width || p.y >= t.height) continue;
            const f = p.x / t.width;
            return { key: t.pinKey, kind: t.pinKind, place: t.place,
                     zone: f < 0.25 ? "before" : f > 0.75 ? "after" : "on" };
        }
        return null;
    }
    function dragStart(info) { dragging = info; dropHint = null; }
    function dragMove(pt) {
        dragAt = pt;
        const h = pinnedAt(pt);
        if (!h || h.key === dragging.key) { dropHint = null; return; }
        // a folder never goes into anything: next to it instead
        if (h.zone === "on" && dragging.kind === "folder") h.zone = "before";
        dropHint = { key: h.key, zone: h.zone, kind: h.kind, place: h.place };
    }
    function dragEnd() {
        const src = dragging, h = dropHint;
        dragging = null;
        dropHint = null;
        if (!src || !h) return;
        if (h.zone === "on") {
            if (h.kind === "folder") app.addToFolder(h.key, src.key);
            else app.makeFolder(h.key, src.key);
            return;
        }
        const from = app.pinIndex(src.key);
        let to = h.place + (h.zone === "after" ? 1 : 0);
        if (from < to) to -= 1;      // its own place goes away first
        app.movePinTo(src.key, to);
    }
    property string category: "all"
    property string query: ""
    property int selected: 0
    property string tab: "all"     // the search panel's filter
    onTabChanged: selected = 0
    readonly property bool searching: query.trim().length > 0
    readonly property var results: app.searchIn(query, tab)
    // for the search panel (common/SearchPanel.qml), the same one the
    // taskbar's search box shows
    readonly property var owner: app
    function stopTyping() { reset(); }
    readonly property int pad: 28          // left and right edge of the content
    readonly property bool playing: Settings.showNowPlaying && !!(app.media && app.media.title)

    function reset() {
        search.text = "";
        view = "home";
        category = "all";
        tab = "all";
        pinnedExpanded = false;
        closePanel();
        selected = 0;
        search.forceActiveFocus();
    }
    function activate(item) {
        if (!item) return;
        if (item.kind === "app" || item.kind === "setting") app.launch(item.id);
        else if (item.kind === "file") app.openUrl(item.url);
        else if (item.kind === "action") app.session(item.id);
    }

    readonly property var categories: [
        { id: "all", label: "All" },
        { id: "internet", label: "Internet" },
        { id: "development", label: "Development" },
        { id: "multimedia", label: "Multimedia" },
        { id: "games", label: "Games" },
        { id: "utilities", label: "Office and tools" },
        { id: "system", label: "System" }
    ]

    // The All apps list: apps A to Z with a letter heading before each new
    // first letter (digits and symbols share "#").
    readonly property var allRows: {
        const list = (category === "all" ? app.apps : app.inCategory(category)).slice();
        list.sort((a, b) => a.name.localeCompare(b.name));
        const rows = [];
        let last = "";
        for (const a of list) {
            const c = a.name.charAt(0).toUpperCase();
            const letter = c.toLowerCase() !== c ? c : "#";
            if (letter !== last) {
                rows.push({ kind: "letter", name: letter });
                last = letter;
            }
            rows.push({ kind: "app", id: a.id, name: a.name, icon: a.icon });
        }
        return rows;
    }

    // ---- the new design's page, as rows (one ListView: only the rows on
    // screen are made, so it opens at once however many apps there are) ----
    readonly property int pinCols: 8
    // the categories, in Windows' manner (from main.qml's categoryOf)
    readonly property var catOrder: [
        { id: "utilities", label: "Productivity" },
        { id: "internet", label: "Internet" },
        { id: "multimedia", label: "Creativity" },
        { id: "development", label: "Development" },
        { id: "games", label: "Games" },
        { id: "system", label: "System" }
    ]
    function catLabel(id) { const c = catOrder.find(x => x.id === id); return c ? c.label : ""; }
    readonly property var sortedApps: (app.apps || []).slice().sort((a, b) => a.name.localeCompare(b.name))
    readonly property var homeRows: {
        if (!modern) return [];
        const rows = [];
        const pins = app.pinnedItems || [];
        rows.push({ kind: "pinnedHeader" });
        if (pins.length === 0) rows.push({ kind: "note", text: "Right-click an app below to pin it here." });
        for (let i = 0, r = 0; i < pins.length && (pinnedExpanded || r < 2); i += pinCols, r++)
            rows.push({ kind: "pinnedRow", apps: pins.slice(i, i + pinCols), first: i });
        rows.push({ kind: "recentHeader" });
        const rec = app.recent || [];
        if (rec.length === 0) rows.push({ kind: "note", text: "Files you open will show up here." });
        for (let i = 0; i < Math.min(rec.length, 6); i += 3)
            rows.push({ kind: "recentRow", files: rec.slice(i, i + 3) });
        if (playing) rows.push({ kind: "media" });
        rows.push({ kind: "allHeader" });
        const v = Settings.startView;
        if (v === "category") {
            const cats = catOrder.map(c => ({ id: c.id, label: c.label,
                                              apps: sortedApps.filter(a => app.categoryOf(a) === c.id) }))
                                 .filter(c => c.apps.length > 0);
            for (let i = 0; i < cats.length; i += 4)
                rows.push({ kind: "catRow", cats: cats.slice(i, i + 4) });
        } else {
            let letter = "", group = [];
            const flush = () => {
                if (!group.length) return;
                rows.push({ kind: "letter", name: letter });
                if (v === "grid")
                    for (let i = 0; i < group.length; i += 7) rows.push({ kind: "gridRow", apps: group.slice(i, i + 7) });
                else
                    for (const a of group) rows.push({ kind: "listRow", app: a });
                group = [];
            };
            for (const a of sortedApps) {
                const c = a.name.charAt(0).toUpperCase();
                const l = c.toLowerCase() !== c ? c : "#";
                if (l !== letter) { flush(); letter = l; }
                group.push(a);
            }
            flush();
        }
        rows.push({ kind: "end" });
        return rows;
    }
    readonly property var openCategoryApps: openCategory === "" ? [] : sortedApps.filter(a => app.categoryOf(a) === openCategory)

    // ---- pieces ---------------------------------------------------------------

    component Label: Text {
        property bool strong: false
        font.family: sm.pal.font
        font.pixelSize: 13
        font.weight: strong ? Font.DemiBold : Font.Normal
        color: sm.pal.text1
        elide: Text.ElideRight
        textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
    }

    // A small framed text button with an optional arrow ("All apps >", "< Back").
    component PillButton: Rectangle {
        id: pill
        property string text
        property string leading: ""
        property string trailing: ""
        signal clicked()
        width: pillRow.implicitWidth + 20
        height: 26
        radius: 6
        color: pillArea.containsMouse ? sm.pal.tintHover : sm.pal.tint
        border.width: 1
        border.color: sm.pal.stroke
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            Glyph {
                visible: pill.leading !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: pill.leading; size: 16; wght: 300
                color: sm.pal.text1; fontAvailable: sm.pal.hasIconFont
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: pill.text; font.pixelSize: 12 }
            Glyph {
                visible: pill.trailing !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: pill.trailing; size: 16; wght: 300
                color: sm.pal.text1; fontAvailable: sm.pal.hasIconFont
            }
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // A section heading with a button on the right ("Pinned ... All apps >").
    component SectionHeader: Item {
        id: header
        property string text
        property string button
        property string leading: ""
        property string trailing: ""
        signal clicked()
        width: parent ? parent.width : 0
        height: 28
        Label { x: 8; anchors.verticalCenter: parent.verticalCenter; text: header.text; strong: true; font.pixelSize: 14 }
        PillButton {
            visible: header.button !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: header.button; leading: header.leading; trailing: header.trailing
            onClicked: header.clicked()
        }
    }

    component AppTile: Item {
        id: tile
        required property var modelData
        property bool pinnedTile: false   // in Pinned: its menu can move it
        property string folderKey: ""     // in an app folder (the folder's entry)
        property int place: -1            // in Pinned: its place there
        // for dragging (sm.pinnedAt)
        readonly property string pinKey: pinnedTile && modelData ? (modelData.id || "") : ""
        readonly property string pinKind: "app"
        // faded in its old place while it is being dragged
        opacity: sm.dragging && pinKey !== "" && sm.dragging.key === pinKey ? 0.35 : 1
        Component.onCompleted: if (pinnedTile) sm.registerTile(tile)
        Component.onDestruction: sm.unregisterTile(tile)
        DropMark { key: tile.pinKey }
        width: 96
        height: 84
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: tileArea.containsMouse ? sm.pal.tintHover : "transparent"
        }
        Kirigami.Icon {
            id: tileIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: 32
            height: 32
            source: tile.modelData.icon || "application-x-executable"
            fallback: "application-x-executable"
        }
        Label {
            anchors.top: tileIcon.bottom
            anchors.topMargin: 9
            x: 4
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: tile.modelData.name
            font.pixelSize: 12
        }
        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: tile.pinnedTile && sm.modern   // a drag moves the app, not the page
            property point pressAt
            property bool dragged: false
            onPressed: mouse => { pressAt = Qt.point(mouse.x, mouse.y); dragged = false; }
            onPositionChanged: mouse => {
                if (!pressed || !(pressedButtons & Qt.LeftButton) || !tile.pinnedTile || !sm.modern) return;
                if (!dragged && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 8) {
                    dragged = true;
                    sm.dragStart({ key: tile.pinKey, kind: "app", icon: tile.modelData.icon });
                }
                if (dragged) sm.dragMove(mapToItem(sm, mouse.x, mouse.y));
            }
            onReleased: if (dragged) sm.dragEnd()
            onCanceled: if (dragged) { sm.dragging = null; sm.dropHint = null; }
            onClicked: mouse => {
                if (dragged) { dragged = false; return; }
                if (mouse.button === Qt.RightButton) sm.showAppMenu(tile.modelData, tile, mouse.x, mouse.y, tile.pinnedTile, tile.folderKey);
                else sm.app.launch(tile.modelData.id);
            }
        }
        QQC2.ToolTip.visible: tileArea.containsMouse && tile.modelData.name.length > 14
        QQC2.ToolTip.text: tile.modelData.name
        QQC2.ToolTip.delay: 700
    }

    // A recent file: its icon, its name, and "folder · when" under it.
    component FileRow: Item {
        id: fileRow
        required property var modelData
        height: 52
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: fileArea.containsMouse ? sm.pal.tintHover : "transparent"
        }
        Kirigami.Icon {
            id: fileIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            source: fileRow.modelData.icon || (fileRow.modelData.folder ? "folder" : "text-x-generic")
            fallback: fileRow.modelData.folder ? "folder" : "text-x-generic"
        }
        Column {
            anchors.left: fileIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { width: parent.width; text: fileRow.modelData.name }
            Label {
                width: parent.width
                text: sm.app.fileWhere(fileRow.modelData)
                font.pixelSize: 12
                color: sm.pal.text2
            }
        }
        MouseArea {
            id: fileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) sm.showFileMenu(fileRow.modelData, fileRow, mouse.x, mouse.y);
                else sm.app.openUrl(fileRow.modelData.url);
            }
        }
    }

    // A row in the search results or the All apps list.
    component ListRow: Item {
        id: row
        property var item
        property bool isSelected: false
        property bool tall: false
        signal hovered()
        width: parent ? parent.width : 0
        height: tall ? 50 : 40
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: row.isSelected || rowArea.containsMouse ? sm.pal.tintHover : "transparent"
        }
        Rectangle {
            visible: row.isSelected
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 16
            radius: 1.5
            color: sm.pal.blue
        }
        Item {
            id: rowIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: row.tall ? 28 : 24
            height: width
            Kirigami.Icon {
                anchors.fill: parent
                visible: row.item.kind !== "action"
                source: row.item.icon || (row.item.kind === "app" ? "application-x-executable" : "text-x-generic")
                fallback: row.item.kind === "app" ? "application-x-executable" : "text-x-generic"
            }
            Glyph {
                anchors.centerIn: parent
                visible: row.item.kind === "action"
                name: row.item.glyph || ""
                size: 20; wght: 300
                color: sm.pal.text1
                fontAvailable: sm.pal.hasIconFont
            }
        }
        Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: hint.visible ? hint.left : parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { width: parent.width; text: row.item.name }
            Label {
                visible: row.tall && text.length > 0
                width: parent.width
                text: row.item.description || ""
                font.pixelSize: 12
                color: sm.pal.text2
            }
        }
        Label {
            id: hint
            visible: row.isSelected && sm.searching
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter to open"
            font.pixelSize: 12
            color: sm.pal.text3
        }
        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: row.hovered()
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (row.item.kind === "app")
                        sm.showAppMenu(row.item, row, mouse.x, mouse.y);
                } else {
                    sm.activate(row.item);
                }
            }
        }
    }

    // ---- the new design's pieces ----------------------------------------------

    // A section title with a plain text button on the right, like Windows:
    // "Pinned ... Show all v", "Recent ... Show all >", "All ... View: Category v".
    component HeaderRow: Item {
        id: hr
        property string title
        property string button: ""
        property string glyph: ""
        signal clicked()
        height: 46
        Label { x: 8; y: 14; text: hr.title; strong: true; font.pixelSize: 14 }
        Rectangle {
            id: hrButton
            visible: hr.button !== ""
            anchors.right: parent.right
            y: 8
            width: hrRow.implicitWidth + 20
            height: 30
            radius: 6
            color: hrArea.containsMouse ? sm.pal.tintHover : "transparent"
            Row {
                id: hrRow
                anchors.centerIn: parent
                spacing: 6
                Label { anchors.verticalCenter: parent.verticalCenter; text: hr.button; font.pixelSize: 13 }
                Glyph {
                    visible: hr.glyph !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    name: hr.glyph; size: 16; wght: 300
                    color: sm.pal.text1; fontAvailable: sm.pal.hasIconFont
                }
            }
            MouseArea {
                id: hrArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: hr.clicked()
            }
        }
        // where the View menu opens
        readonly property Item buttonItem: hrButton
    }

    // A recent file in the new design: its icon, its name and when; the
    // folder shows on hover (like Windows' card).
    component RecentCell: Item {
        id: rc
        property var file
        height: 56
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: rcArea.containsMouse ? sm.pal.tintHover : "transparent"
        }
        Kirigami.Icon {
            id: rcIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32
            source: rc.file ? (rc.file.icon || (rc.file.folder ? "folder" : "text-x-generic")) : ""
            fallback: rc.file && rc.file.folder ? "folder" : "text-x-generic"
        }
        Column {
            anchors.left: rcIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { width: parent.width; text: rc.file ? rc.file.name : "" }
            Label {
                width: parent.width
                text: rc.file ? sm.app.ago(rc.file.when) : ""
                font.pixelSize: 12
                color: sm.pal.text2
            }
        }
        MouseArea {
            id: rcArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (!rc.file) return;
                if (mouse.button === Qt.RightButton) sm.showFileMenu(rc.file, rc, mouse.x, mouse.y);
                else sm.app.openUrl(rc.file.url);
            }
        }
        QQC2.ToolTip.visible: rcArea.containsMouse && !!rc.file
        QQC2.ToolTip.text: rc.file ? rc.file.name + "\n" + sm.app.fileWhere(rc.file) : ""
        QQC2.ToolTip.delay: 600
    }

    // A category in the new design: a tile with up to four of its apps
    // (click one to open it) and the name under it; the rest of the tile
    // opens the whole category.
    component CategoryTile: Item {
        id: ct
        property var cat
        height: width + 28
        // the tile and its name open the whole category (its icons open apps)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (ct.cat) sm.openCategory = ct.cat.id
        }
        Rectangle {
            id: ctBox
            x: 8
            width: parent.width - 16
            height: width
            radius: 8
            color: sm.pal.tint
            border.width: 1
            border.color: sm.pal.stroke
            // always a 2 x 2 frame, filled from the top left (like Windows)
            Grid {
                anchors.centerIn: parent
                width: 2 * Math.round(ctBox.width * 0.3) + spacing
                height: width
                columns: 2
                spacing: Math.round(ctBox.width * 0.1)
                Repeater {
                    model: ct.cat ? ct.cat.apps.slice(0, 4) : []
                    Rectangle {
                        id: ctApp
                        required property var modelData
                        width: Math.round(ctBox.width * 0.3)
                        height: width
                        radius: 6
                        color: ctAppArea.containsMouse ? sm.pal.tintHover : "transparent"
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.75); height: width
                            source: ctApp.modelData.icon || "application-x-executable"
                            fallback: "application-x-executable"
                        }
                        MouseArea {
                            id: ctAppArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) sm.showAppMenu(ctApp.modelData, ctApp, mouse.x, mouse.y);
                                else sm.app.launch(ctApp.modelData.id);
                            }
                        }
                        QQC2.ToolTip.visible: ctAppArea.containsMouse
                        QQC2.ToolTip.text: ctApp.modelData.name
                        QQC2.ToolTip.delay: 600
                    }
                }
            }
        }
        Label {
            anchors.top: ctBox.bottom
            anchors.topMargin: 6
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ct.cat ? ct.cat.label : ""
            font.pixelSize: 12
        }
    }

    // Where a dragged pinned app would land: an outline over the tile (into a
    // folder) or a line at its edge (moved there).
    component DropMark: Item {
        property string key
        anchors.fill: parent
        readonly property var hint: sm.dropHint && key !== "" && sm.dropHint.key === key ? sm.dropHint : null
        Rectangle {
            visible: !!parent.hint && parent.hint.zone === "on"
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: sm.pal.tintHover
            border.width: 2
            border.color: sm.pal.blue
        }
        Rectangle {
            visible: !!parent.hint && parent.hint.zone !== "on"
            x: parent.hint && parent.hint.zone === "after" ? parent.width - 2 : 0
            y: 10
            width: 3; height: parent.height - 20
            radius: 1.5
            color: sm.pal.blue
        }
    }

    // An app folder in Pinned, like Windows: a rounded square with up to four
    // of its apps, and its name. Click: open it; right-click: move it.
    component FolderTile: Item {
        id: ft
        property var folder: null
        property int place: -1            // its place in Pinned
        readonly property string pinKey: folder ? folder.key : ""
        readonly property string pinKind: "folder"
        opacity: sm.dragging && pinKey !== "" && sm.dragging.key === pinKey ? 0.35 : 1
        Component.onCompleted: sm.registerTile(ft)
        Component.onDestruction: sm.unregisterTile(ft)
        height: 84
        DropMark { key: ft.pinKey }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 8
            color: ftArea.containsMouse ? sm.pal.tintHover : "transparent"
        }
        Rectangle {
            id: ftBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 40; height: 40
            radius: 8
            color: sm.pal.tintHover
            border.width: 1
            border.color: sm.pal.stroke
            Grid {
                x: 5; y: 5
                width: 30; height: 30
                columns: 2
                spacing: 2
                Repeater {
                    model: ft.folder ? ft.folder.apps.slice(0, 4) : []
                    Kirigami.Icon {
                        required property var modelData
                        width: 14; height: 14
                        source: modelData.icon || "application-x-executable"
                        fallback: "application-x-executable"
                    }
                }
            }
        }
        Label {
            anchors.top: ftBox.bottom
            anchors.topMargin: 7
            x: 4
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: ft.folder ? ft.folder.name : ""
            font.pixelSize: 12
        }
        MouseArea {
            id: ftArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            property point pressAt
            property bool dragged: false
            onPressed: mouse => { pressAt = Qt.point(mouse.x, mouse.y); dragged = false; }
            onPositionChanged: mouse => {
                if (!pressed || !(pressedButtons & Qt.LeftButton) || !ft.folder) return;
                if (!dragged && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 8) {
                    dragged = true;
                    sm.dragStart({ key: ft.pinKey, kind: "folder", folder: ft.folder });
                }
                if (dragged) sm.dragMove(mapToItem(sm, mouse.x, mouse.y));
            }
            onReleased: if (dragged) sm.dragEnd()
            onCanceled: if (dragged) { sm.dragging = null; sm.dropHint = null; }
            onClicked: mouse => {
                if (dragged) { dragged = false; return; }
                if (!ft.folder) return;
                if (mouse.button === Qt.RightButton) {
                    folderMenu.key = ft.folder.key;
                    folderMenu.visualParent = ft;
                    folderMenu.open(mouse.x, mouse.y);
                } else {
                    sm.openCategory = "";
                    sm.openFolder = ft.place;
                }
            }
        }
    }
    // a folder's own menu: only where it goes (like Windows)
    PlasmaExtras.Menu {
        id: folderMenu
        property string key: ""
        readonly property int at: key !== "" ? sm.app.pinIndex(key) : -1
        readonly property int count: (sm.app.pinnedItems || []).length
        PlasmaExtras.MenuItem {
            visible: folderMenu.at > 0
            text: "Move to front"; icon: "go-first"
            onClicked: sm.app.movePin(folderMenu.key, "front")
        }
        PlasmaExtras.MenuItem {
            visible: folderMenu.at > 0
            text: "Move left"; icon: "go-previous"
            onClicked: sm.app.movePin(folderMenu.key, -1)
        }
        PlasmaExtras.MenuItem {
            visible: folderMenu.at >= 0 && folderMenu.at < folderMenu.count - 1
            text: "Move right"; icon: "go-next"
            onClicked: sm.app.movePin(folderMenu.key, 1)
        }
    }

    // ---- the new design's View menu: category, grid, list -------------------
    PlasmaExtras.Menu {
        id: viewMenu
        PlasmaExtras.MenuItem {
            text: "Category"; checkable: true; checked: Settings.startView === "category"
            onClicked: sm.app.setStartView("category")
        }
        PlasmaExtras.MenuItem {
            text: "Grid"; checkable: true; checked: Settings.startView === "grid"
            onClicked: sm.app.setStartView("grid")
        }
        PlasmaExtras.MenuItem {
            text: "List"; checkable: true; checked: Settings.startView === "list"
            onClicked: sm.app.setStartView("list")
        }
    }
    function viewName(v) { return v === "grid" ? "Grid" : v === "list" ? "List" : "Category"; }

    // ---- right-click on any app (tile, list or search result) -----------------------
    // Plasma's own menu type, so it opens as a proper menu window.
    // The app's own actions from its .desktop file (New window, New private
    // window...), the Linux version of a Windows jump list. A Menu only takes
    // menu items as children, so they are made here each time it opens, the
    // way Plasma's own taskbar menu does it.
    property var actionItems: []
    Component {
        id: actionItem
        PlasmaExtras.MenuItem {
            property string appId
            property string actionId
            onClicked: sm.app.launchAction(appId, actionId)
        }
    }
    function showAppMenu(app, item, x, y, pinned, folderKey) {
        appMenu.fromPinned = !!pinned;
        appMenu.folderKey = folderKey || "";
        // Search results and tiles may carry only id/name/icon: use the full app
        // entry (which has the actions) whenever there is one.
        const full = app ? (sm.app.apps || []).find(a => a.id === app.id) : null;
        if (full) app = full;
        for (const old of actionItems) { appMenu.removeMenuItem(old); old.destroy(); }
        const made = [];
        for (const a of (app && app.actions) || []) {
            const mi = actionItem.createObject(appMenu, {
                text: a.name, icon: a.icon || app.icon || "", appId: app.id, actionId: a.id });
            if (mi) { appMenu.addMenuItem(mi, actionsEnd); made.push(mi); }
        }
        actionItems = made;
        appMenu.target = app;
        appMenu.visualParent = item;
        appMenu.open(x, y);
    }
    PlasmaExtras.Menu {
        id: appMenu
        property var target: null
        property bool fromPinned: false     // opened on a pinned app: it can be moved
        property string folderKey: ""       // opened on an app in an app folder
        readonly property string targetId: target ? target.id : ""
        readonly property int pinAt: fromPinned && targetId !== "" ? sm.app.pinIndex(targetId) : -1
        readonly property int pinCount: (sm.app.pinnedItems || []).length
        readonly property bool onStart: targetId !== "" && sm.app.isPinned(targetId)
        readonly property bool onTaskbar: targetId !== "" && sm.app.isOnTaskbar(targetId)

        // a pinned app's place, like Windows ("Move to front / left / right")
        PlasmaExtras.MenuItem {
            visible: appMenu.pinAt > 0
            text: "Move to front"
            icon: "go-first"
            onClicked: sm.app.movePin(appMenu.targetId, "front")
        }
        PlasmaExtras.MenuItem {
            visible: appMenu.pinAt > 0
            text: "Move left"
            icon: "go-previous"
            onClicked: sm.app.movePin(appMenu.targetId, -1)
        }
        PlasmaExtras.MenuItem {
            visible: appMenu.pinAt >= 0 && appMenu.pinAt < appMenu.pinCount - 1
            text: "Move right"
            icon: "go-next"
            onClicked: sm.app.movePin(appMenu.targetId, 1)
        }
        PlasmaExtras.MenuItem {
            visible: appMenu.pinAt >= 0 && sm.modern
            text: "Create a new app folder"
            icon: "folder-new"
            onClicked: sm.app.createFolder(appMenu.targetId)
        }
        PlasmaExtras.MenuItem {
            visible: appMenu.folderKey !== ""
            text: "Remove from app folder"
            icon: "edit-remove"
            onClicked: sm.app.removeFromFolder(appMenu.folderKey, appMenu.targetId)
        }
        PlasmaExtras.MenuItem { visible: appMenu.pinAt >= 0 || appMenu.folderKey !== ""; separator: true }
        PlasmaExtras.MenuItem {
            text: "Open"
            icon: "system-run"
            onClicked: sm.app.launch(appMenu.targetId)
        }
        // (the app's own actions are inserted here by showAppMenu)
        PlasmaExtras.MenuItem { id: actionsEnd; separator: true }
        PlasmaExtras.MenuItem {
            text: appMenu.onStart ? "Unpin from Start" : "Pin to Start"
            icon: appMenu.onStart ? "window-unpin" : "window-pin"
            onClicked: sm.app.togglePin(appMenu.targetId)
        }
        PlasmaExtras.MenuItem {
            text: appMenu.onTaskbar ? "Unpin from taskbar" : "Pin to taskbar"
            icon: appMenu.onTaskbar ? "window-unpin" : "window-pin"
            onClicked: sm.app.toggleTaskbar(appMenu.targetId)
        }
    }

    // ---- right-click on a recent file ------------------------------------------------
    // Like Windows: Open file location, and Remove from list (only off this
    // menu; the system's own list of recent files stays as it is).
    function showFileMenu(file, item, x, y) {
        fileMenu.target = file;
        fileMenu.visualParent = item;
        fileMenu.open(x, y);
    }
    PlasmaExtras.Menu {
        id: fileMenu
        property var target: null
        PlasmaExtras.MenuItem {
            text: "Open"
            icon: "document-open"
            onClicked: if (fileMenu.target) sm.app.openUrl(fileMenu.target.url)
        }
        PlasmaExtras.MenuItem {
            text: "Open file location"
            icon: "folder-open"
            onClicked: if (fileMenu.target) sm.app.revealFile(fileMenu.target.url)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            text: "Remove from list"
            icon: "list-remove"
            onClicked: if (fileMenu.target) sm.app.hideRecent(fileMenu.target.url)
        }
    }

    // ---- search box ---------------------------------------------------------------

    Rectangle {
        id: searchBox
        x: sm.pad
        y: 22
        width: parent.width - 2 * sm.pad
        height: 38
        radius: height / 2
        // typing, like Windows: darker, a grey outline and a blue magnifier
        // (no blue line)
        color: search.activeFocus && sm.searching ? sm.pal.alpha(sm.pal.dark ? "black" : "white", 0.25) : sm.pal.tint
        border.width: 1
        border.color: search.activeFocus && sm.searching ? sm.pal.alpha(sm.pal.text1, 0.25) : sm.pal.stroke
        Glyph {
            id: lens
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "search"; fallback: "search"
            svg: "search"   // the user's own magnifier (common/Glyph.qml)
            size: 18; wght: 300
            color: sm.searching ? sm.pal.blue : sm.pal.text2
            fontAvailable: sm.pal.hasIconFont
        }
        QQC2.TextField {
            id: search
            anchors.left: lens.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 30
            focus: true
            color: sm.pal.text1
            selectionColor: sm.pal.blue
            selectedTextColor: sm.pal.blueText
            font.family: sm.pal.font
            font.pixelSize: 13
            background: null
            leftPadding: 2
            placeholderText: ""
            onTextChanged: {
                sm.query = text;
                sm.selected = 0;
                sm.app.searchFiles(text);
            }
            Keys.onDownPressed: sm.selected = Math.max(0, Math.min(sm.results.length - 1, sm.selected + 1))
            Keys.onUpPressed: sm.selected = Math.max(0, sm.selected - 1)
            Keys.onReturnPressed: sm.activate(sm.results[sm.selected])
            Keys.onEnterPressed: sm.activate(sm.results[sm.selected])
            // Escape closes the menu, like Windows (checked on Windows 11:
            // from search and from a sub-page alike; the back arrows are the
            // way back), except with a category or app folder open: then it
            // closes just that
            Keys.onEscapePressed: {
                if (sm.panelOpen) sm.closePanel();
                else sm.app.close();
            }
        }
        Label {
            anchors.left: lens.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0
            text: sm.modern ? "Search for apps, settings, and documents" : "Search apps and files, or type > for actions"
            color: sm.pal.text3
        }
    }

    // The area between the search box and the bottom bar.
    Item {
        id: body
        x: sm.pad - 8
        y: searchBox.y + searchBox.height + 22
        width: parent.width - 2 * (sm.pad - 8)
        // searching: the panel takes the whole menu, no bottom bar (like Windows)
        height: (sm.searching ? parent.height : footer.y - 12) - y

        // ---- searching: the same panel as the taskbar's search box ----
        SearchPanel {
            visible: sm.searching
            anchors.fill: parent
            anchors.topMargin: -14
            box: sm
            pal: sm.pal
        }

        // ---- the new design: one page that scrolls ----
        ListView {
            id: homeList
            visible: !sm.searching && sm.modern && sm.view === "home"
            anchors.fill: parent
            anchors.topMargin: -8
            rightMargin: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            model: visible ? sm.homeRows : []
            QQC2.ScrollBar.vertical: ThinScrollBar { tint: sm.pal.text2 }
            Connections {
                target: sm
                function onViewChanged() { if (sm.view === "home") homeList.positionViewAtBeginning(); }
            }
            delegate: Loader {
                id: rowLoader
                required property var modelData
                readonly property var row: modelData
                readonly property int w: homeList.width - homeList.rightMargin
                width: w
                sourceComponent: {
                    switch (modelData.kind) {
                    case "pinnedHeader": return pinnedHeaderRow;
                    case "recentHeader": return recentHeaderRow;
                    case "allHeader": return allHeaderRow;
                    case "pinnedRow": return pinnedRowC;
                    case "recentRow": return recentRowC;
                    case "media": return mediaRowC;
                    case "catRow": return catRowC;
                    case "letter": return letterRowC;
                    case "gridRow": return gridRowC;
                    case "listRow": return listRowC;
                    case "note": return noteRowC;
                    default: return endRowC;
                    }
                }
            }
        }
        Component {
            id: pinnedHeaderRow
            HeaderRow {
                width: parent ? parent.w : 0
                title: "Pinned"
                // two rows show; the rest behind "Show all", like Windows
                button: (sm.app.pinnedItems || []).length > 2 * sm.pinCols ? (sm.pinnedExpanded ? "Show less" : "Show all") : ""
                glyph: sm.pinnedExpanded ? "expand_less" : "expand_more"
                onClicked: sm.pinnedExpanded = !sm.pinnedExpanded
            }
        }
        Component {
            id: recentHeaderRow
            HeaderRow {
                width: parent ? parent.w : 0
                title: "Recent"
                button: (sm.app.recent || []).length > 0 ? "Show all" : ""
                glyph: "chevron_right"
                onClicked: sm.view = "recent"
            }
        }
        Component {
            id: allHeaderRow
            HeaderRow {
                id: allHead
                width: parent ? parent.w : 0
                title: "All"
                button: "View: " + sm.viewName(Settings.startView)
                glyph: "expand_more"
                onClicked: {
                    viewMenu.visualParent = allHead.buttonItem;
                    viewMenu.openRelative();
                }
            }
        }
        Component {
            id: pinnedRowC
            Row {
                id: pinRow
                readonly property int cell: Math.floor((parent ? parent.w : 0) / sm.pinCols)
                readonly property var rowData: parent ? parent.row : null
                Repeater {
                    model: pinRow.rowData ? pinRow.rowData.apps : []
                    Item {
                        id: pinCell
                        required property var modelData
                        required property int index
                        readonly property bool folder: modelData.kind === "folder"
                        width: pinRow.cell
                        height: 84
                        AppTile {
                            visible: !pinCell.folder
                            modelData: pinCell.folder ? ({ id: "", name: "", icon: "" }) : pinCell.modelData
                            width: pinCell.width
                            pinnedTile: !pinCell.folder
                            place: pinRow.rowData ? pinRow.rowData.first + pinCell.index : -1
                        }
                        FolderTile {
                            visible: pinCell.folder
                            folder: pinCell.folder ? pinCell.modelData : null
                            place: pinRow.rowData ? pinRow.rowData.first + pinCell.index : -1
                            width: pinCell.width
                        }
                    }
                }
            }
        }
        Component {
            id: recentRowC
            Row {
                Repeater {
                    model: parent && parent.parent ? parent.parent.row.files : []
                    RecentCell {
                        required property var modelData
                        file: modelData
                        width: Math.floor((parent && parent.parent ? parent.parent.w : 0) / 3)
                    }
                }
            }
        }
        Component {
            id: mediaRowC
            Item {
                height: 68
                MediaCard { y: 4; x: 8; width: (parent.parent ? parent.parent.w : 0) - 16 }
            }
        }
        Component {
            id: catRowC
            Row {
                readonly property int cell: Math.floor((parent ? parent.w : 0) / 4)
                Repeater {
                    model: parent && parent.parent ? parent.parent.row.cats : []
                    CategoryTile {
                        required property var modelData
                        cat: modelData
                        width: parent.cell
                    }
                }
            }
        }
        Component {
            id: letterRowC
            Item {
                height: 40
                Label { x: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.parent ? parent.parent.row.name : ""; strong: true }
            }
        }
        Component {
            id: gridRowC
            Row {
                readonly property int cell: Math.floor((parent ? parent.w : 0) / 7)
                Repeater {
                    model: parent && parent.parent ? parent.parent.row.apps : []
                    AppTile { width: parent.cell }
                }
            }
        }
        Component {
            id: listRowC
            ListRow {
                width: parent ? parent.w : 0
                item: parent ? ({ kind: "app", id: parent.row.app.id, name: parent.row.app.name, icon: parent.row.app.icon }) : ({ kind: "app" })
            }
        }
        Component {
            id: noteRowC
            Item {
                height: 34
                Label { x: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.parent ? parent.parent.row.text : ""; color: sm.pal.text2 }
            }
        }
        Component { id: endRowC; Item { height: 12 } }

        // ---- the new design: a category, opened from its tile ----
        MouseArea {
            // a click anywhere else closes it
            visible: catPanel.visible
            anchors.fill: parent
            onClicked: sm.closePanel()
        }
        Rectangle {
            id: catPanel
            visible: sm.panelOpen && homeList.visible
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (parent.height - height) / 2)
            width: 4 * 104 + 40
            height: Math.min(parent.height - 20, catGrid.implicitHeight + 96)
            radius: 10
            color: sm.pal.dark ? "#2b2c32" : "#f7f7f9"
            border.width: 1
            border.color: sm.pal.stroke
            MouseArea { anchors.fill: parent }   // clicks inside stay inside
            Label {
                visible: !sm.openFolderItem
                anchors.horizontalCenter: parent.horizontalCenter
                y: 22
                text: sm.catLabel(sm.openCategory)
                strong: true
                font.pixelSize: 18
            }
            // a folder's name: click it to rename it (like Windows)
            Rectangle {
                objectName: "folderTitle"
                visible: !!sm.openFolderItem
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                width: Math.max(200, folderName.implicitWidth + 40)
                height: 40
                radius: 6
                color: folderName.activeFocus ? sm.pal.alpha(sm.pal.dark ? "black" : "white", 0.25)
                     : nameArea.containsMouse ? sm.pal.tintHover : "transparent"
                border.width: folderName.activeFocus ? 1 : 0
                border.color: sm.pal.stroke
                Rectangle {
                    visible: folderName.activeFocus
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2 * parent.radius
                    height: 2
                    color: sm.pal.blue
                }
                TextInput {
                    id: folderName
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: sm.pal.font
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: sm.pal.text1
                    selectionColor: sm.pal.blue
                    selectedTextColor: sm.pal.blueText
                    clip: true
                    maximumLength: 60
                    readonly property string saved: sm.openFolderItem ? sm.openFolderItem.name : ""
                    onSavedChanged: if (!activeFocus) text = saved
                    Component.onCompleted: text = saved
                    function commit() {
                        if (sm.openFolderItem && text.trim() !== sm.openFolderItem.name)
                            sm.app.renameFolder(sm.openFolderItem.key, text);
                        search.forceActiveFocus();
                    }
                    Keys.onReturnPressed: commit()
                    Keys.onEnterPressed: commit()
                    Keys.onEscapePressed: { text = saved; search.forceActiveFocus(); }
                    onActiveFocusChanged: if (!activeFocus && text.trim() !== saved) commit()
                }
                MouseArea {
                    id: nameArea
                    anchors.fill: parent
                    visible: !folderName.activeFocus
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: { folderName.forceActiveFocus(); folderName.selectAll(); }
                }
            }
            Flickable {
                x: 20
                y: 66
                width: parent.width - 40
                height: parent.height - 86
                contentHeight: catGrid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: ThinScrollBar { tint: sm.pal.text2 }
                Grid {
                    id: catGrid
                    columns: 4
                    Repeater {
                        model: sm.openFolderItem ? sm.openFolderItem.apps : sm.openCategoryApps
                        AppTile { width: 104; folderKey: sm.openFolderItem ? sm.openFolderItem.key : "" }
                    }
                }
            }
        }

        // ---- the classic design: pinned and recommended ----
        Item {
            visible: !sm.searching && !sm.modern && sm.view === "home"
            anchors.fill: parent

            SectionHeader {
                id: pinnedHeader
                text: "Pinned"
                button: "All apps"
                trailing: "chevron_right"
                onClicked: sm.view = "all"
            }
            // three rows of six; more pinned apps scroll
            Flickable {
                id: pinnedArea
                anchors.top: pinnedHeader.bottom
                anchors.topMargin: 8
                width: parent.width
                height: Math.min(3, Math.ceil(Math.max(1, sm.app.pinnedApps.length) / 6)) * 88
                contentHeight: pinnedGrid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                Grid {
                    id: pinnedGrid
                    width: parent.width
                    columns: 6
                    columnSpacing: (width - 6 * 96) / 5
                    rowSpacing: 4
                    Repeater {
                        model: sm.app.pinnedApps
                        AppTile { pinnedTile: true }
                    }
                }
                Label {
                    visible: sm.app.pinnedApps.length === 0
                    x: 8
                    y: 8
                    text: "Right-click an app in All apps to pin it here."
                    color: sm.pal.text2
                }
            }

            SectionHeader {
                id: recHeader
                anchors.top: pinnedArea.bottom
                anchors.topMargin: 18
                text: "Recommended"
                button: sm.app.recent.length > 0 ? "More" : ""
                trailing: "chevron_right"
                onClicked: sm.view = "recent"
            }
            Grid {
                id: recGrid
                anchors.top: recHeader.bottom
                anchors.topMargin: 8
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 2
                Repeater {
                    // three rows, two while the now-playing strip is showing
                    model: sm.app.recent.slice(0, sm.playing ? 4 : 6)
                    FileRow { width: (recGrid.width - 8) / 2 }
                }
            }
            Label {
                visible: sm.app.recent.length === 0
                anchors.top: recHeader.bottom
                anchors.topMargin: 14
                x: 8
                text: "Files you open will show up here."
                color: sm.pal.text2
            }

            // ---- now playing (only while something plays; can be turned off) ----
            MediaCard {
                visible: sm.playing
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }

        // ---- All apps ----
        Item {
            visible: !sm.searching && sm.view === "all"
            anchors.fill: parent

            SectionHeader {
                id: allHeader
                text: "All apps"
                button: "Back"
                leading: "chevron_left"
                onClicked: sm.view = "home"
            }
            Flow {
                id: chips
                anchors.top: allHeader.bottom
                anchors.topMargin: 10
                x: 8
                width: parent.width - 16
                spacing: 6
                Repeater {
                    model: sm.categories
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: sm.category === modelData.id
                        width: chipText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: current ? sm.pal.blue : chipArea.containsMouse ? sm.pal.tintHover : sm.pal.tint
                        border.width: current ? 0 : 1
                        border.color: sm.pal.stroke
                        Label {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            font.pixelSize: 12
                            strong: chip.current
                            color: chip.current ? sm.pal.blueText : sm.pal.text1
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sm.category = chip.modelData.id
                        }
                    }
                }
            }
            // A ListView only makes the rows that are on screen (and a few more as
            // you scroll), so the list opens at once however many apps there are.
            ListView {
                id: allList
                anchors.top: chips.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                width: parent.width
                rightMargin: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: sm.allRows
                reuseItems: true
                QQC2.ScrollBar.vertical: ThinScrollBar { tint: sm.pal.text2 }
                // back to the top when the filter changes
                Connections {
                    target: sm
                    function onCategoryChanged() { allList.positionViewAtBeginning(); }
                    function onViewChanged() { if (sm.view === "all") allList.positionViewAtBeginning(); }
                }
                delegate: Item {
                    id: entry
                    required property var modelData
                    readonly property bool letter: modelData.kind === "letter"
                    width: allList.width - allList.rightMargin
                    height: letter ? 32 : 40
                    Label {
                        visible: entry.letter
                        leftPadding: 12
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: entry.modelData.name
                        strong: true
                        color: sm.pal.blue
                    }
                    ListRow {
                        visible: !entry.letter
                        item: entry.modelData
                    }
                }
                Label {
                    visible: sm.allRows.length === 0
                    leftPadding: 12
                    topPadding: 8
                    text: "No apps here."
                    color: sm.pal.text2
                }
            }
        }

        // ---- every recent file ----
        Item {
            visible: !sm.searching && sm.view === "recent"
            anchors.fill: parent
            SectionHeader {
                id: recentHeader
                text: sm.modern ? "Recent" : "Recommended"
                button: "Back"
                leading: "chevron_left"
                onClicked: sm.view = "home"
            }
            Flickable {
                anchors.top: recentHeader.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: recentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: ThinScrollBar { tint: sm.pal.text2 }
                Column {
                    id: recentCol
                    width: parent.width - 12
                    spacing: 2
                    Repeater {
                        model: sm.view === "recent" ? sm.app.recent : []
                        FileRow { width: recentCol.width }
                    }
                }
            }
        }
    }

    // What's playing: the cover, title and artist, and the controls.
    component MediaCard: Rectangle {
        height: 56
        radius: 8
        color: sm.pal.tint
        border.width: 1
        border.color: sm.pal.stroke
        readonly property var m: sm.app.media || {}
        Rectangle {
            id: artBox
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 6
            color: sm.pal.tintHover
            clip: true
            Image {
                id: art
                anchors.fill: parent
                source: parent.parent.m.art || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Glyph {
                anchors.centerIn: parent
                visible: !art.visible
                name: "music_note"; fallback: "media-album-cover"
                size: 20; wght: 300
                color: sm.pal.text2
                fontAvailable: sm.pal.hasIconFont
            }
        }
        Column {
            anchors.left: artBox.right
            anchors.leftMargin: 12
            anchors.right: controls.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { width: parent.width; text: parent.parent.m.title || "" }
            Label {
                visible: text.length > 0
                width: parent.width
                text: parent.parent.m.artist || ""
                font.pixelSize: 12
                color: sm.pal.text2
            }
        }
        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            MediaButton { glyph: "skip_previous"; fallback: "media-skip-backward"; onClicked: sm.app.mediaCmd("Previous") }
            MediaButton {
                main: true
                glyph: parent.parent.m.playing ? "pause" : "play_arrow"
                fallback: parent.parent.m.playing ? "media-playback-pause" : "media-playback-start"
                onClicked: sm.app.mediaCmd("PlayPause")
            }
            MediaButton { glyph: "skip_next"; fallback: "media-skip-forward"; onClicked: sm.app.mediaCmd("Next") }
        }
    }

    component MediaButton: Rectangle {
        id: mb
        property string glyph
        property string fallback
        property bool main: false
        signal clicked()
        width: 32
        height: 32
        radius: 16
        color: main ? sm.pal.blue : mbArea.containsMouse ? sm.pal.tintHover : "transparent"
        Glyph {
            anchors.centerIn: parent
            name: mb.glyph; fallback: mb.fallback
            size: 20; wght: 300
            filled: mb.main
            color: mb.main ? sm.pal.blueText : sm.pal.text1
            fontAvailable: sm.pal.hasIconFont
        }
        MouseArea {
            id: mbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    // ---- bottom bar: you, and the power button ------------------------------------

    Item {
        id: footer
        visible: !sm.searching
        anchors.bottom: parent.bottom
        width: parent.width
        height: 60
        Rectangle { width: parent.width; height: 1; color: sm.pal.divider }
        Row {
            x: sm.pad + 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: sm.pal.alpha(sm.pal.blue, 0.25)
                clip: true
                Label {
                    anchors.centerIn: parent
                    visible: !face.visible
                    text: (sm.app.stats.user || "?").charAt(0).toUpperCase()
                    font.pixelSize: 14
                    strong: true
                }
                Image {
                    id: face
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: sm.app.stats.avatar ? "file://" + sm.app.stats.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: sm.app.stats.fullName || sm.app.stats.user || ""
            }
        }
        // Power: the same shut down / restart / log out screen as the panel's
        // power button (can be hidden in Tidewater's settings)
        Rectangle {
            visible: Settings.showMenuPower
            anchors.right: parent.right
            anchors.rightMargin: sm.pad - 4
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 8
            color: powerArea.containsMouse ? sm.pal.tintHover : "transparent"
            Glyph {
                anchors.centerIn: parent
                name: "power_settings_new"; fallback: "system-shutdown"
                size: 20; wght: 300
                color: sm.pal.text1
                fontAvailable: sm.pal.hasIconFont
            }
            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sm.app.session("power")
            }
            QQC2.ToolTip.visible: powerArea.containsMouse
            QQC2.ToolTip.text: "Power"
            QQC2.ToolTip.delay: 500
        }
    }

    // ---- the dragged app or folder, following the pointer ----
    Item {
        visible: !!sm.dragging
        x: sm.dragAt.x - 20
        y: sm.dragAt.y - 20
        width: 40; height: 40
        z: 1000
        opacity: 0.85
        Kirigami.Icon {
            visible: !!sm.dragging && sm.dragging.kind === "app"
            anchors.fill: parent
            source: sm.dragging && sm.dragging.icon ? sm.dragging.icon : "application-x-executable"
        }
        Rectangle {
            visible: !!sm.dragging && sm.dragging.kind === "folder"
            anchors.fill: parent
            radius: 8
            color: sm.pal.tintHover
            border.width: 1
            border.color: sm.pal.stroke
        }
    }

}
