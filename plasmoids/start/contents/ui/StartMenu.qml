// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The start menu (640 x 700), in the manner of Windows 11:
// search on top; pinned apps and recommended (recent) files; a slim
// now-playing strip while something plays; your name and the power button
// at the bottom. "All apps" lists every app A to Z, with filters for the
// app categories; "More" lists every recent file. Typing searches apps,
// files and actions (">" for actions only).
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

    implicitWidth: 640
    implicitHeight: 700

    // float a little away from the panel and the screen edges, like Windows 11
    FloatingPopup {}

    property string view: "home"   // home | all | recent
    property string category: "all"
    property string query: ""
    property int selected: 0
    readonly property bool searching: query.trim().length > 0
    readonly property var results: app.search(query, app.fileResults)
    readonly property int pad: 28          // left and right edge of the content
    readonly property bool playing: Settings.showNowPlaying && !!(app.media && app.media.title)

    function reset() {
        search.text = "";
        view = "home";
        category = "all";
        selected = 0;
        search.forceActiveFocus();
    }
    function activate(item) {
        if (!item) return;
        if (item.kind === "app") app.launch(item.id);
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
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) sm.showAppMenu(tile.modelData, tile, mouse.x, mouse.y);
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
            onClicked: sm.app.openUrl(fileRow.modelData.url)
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
    function showAppMenu(app, item, x, y) {
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
        readonly property string targetId: target ? target.id : ""
        readonly property bool onStart: targetId !== "" && sm.app.isPinned(targetId)
        readonly property bool onTaskbar: targetId !== "" && sm.app.isOnTaskbar(targetId)

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

    // ---- search box ---------------------------------------------------------------

    Rectangle {
        id: searchBox
        x: sm.pad
        y: 22
        width: parent.width - 2 * sm.pad
        height: 38
        radius: height / 2
        color: search.activeFocus ? sm.pal.alpha(sm.pal.dark ? "black" : "white", 0.2) : sm.pal.tint
        border.width: 1
        border.color: sm.pal.stroke
        // the focus line along the bottom
        Rectangle {
            visible: search.activeFocus
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * parent.radius
            height: 2
            radius: 1
            color: sm.pal.blue
        }
        Glyph {
            id: lens
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "search"; fallback: "search"
            size: 18; wght: 300
            color: sm.pal.text2
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
            Keys.onEscapePressed: {
                if (text.length > 0) text = "";
                else if (sm.view !== "home") sm.view = "home";
                else sm.app.close();
            }
        }
        Label {
            anchors.left: lens.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text.length === 0
            text: "Search apps and files, or type > for actions"
            color: sm.pal.text3
        }
    }

    // The area between the search box and the bottom bar.
    Item {
        id: body
        x: sm.pad - 8
        y: searchBox.y + searchBox.height + 22
        width: parent.width - 2 * (sm.pad - 8)
        height: footer.y - y - 12

        // ---- search results, grouped ----
        Flickable {
            visible: sm.searching
            anchors.fill: parent
            contentHeight: resultCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: resultCol
                width: parent.width
                Repeater {
                    model: sm.searching ? sm.results : []
                    Column {
                        id: resultEntry
                        required property var modelData
                        required property int index
                        width: resultCol.width
                        readonly property bool firstOfKind: index === 0 || sm.results[index - 1].kind !== modelData.kind
                        Item { visible: resultEntry.firstOfKind && resultEntry.index > 0; width: 1; height: 8 }
                        Label {
                            visible: resultEntry.firstOfKind
                            leftPadding: 4
                            height: 30
                            verticalAlignment: Text.AlignVCenter
                            text: resultEntry.modelData.kind === "app" ? "Apps"
                                : resultEntry.modelData.kind === "file" ? "Files" : "Actions"
                            font.pixelSize: 12
                            strong: true
                            color: sm.pal.text2
                        }
                        ListRow {
                            item: resultEntry.modelData
                            tall: resultEntry.modelData.kind !== "action"
                            isSelected: resultEntry.index === sm.selected
                            onHovered: sm.selected = resultEntry.index
                        }
                    }
                }
                Label {
                    visible: sm.results.length === 0
                    topPadding: 8
                    leftPadding: 8
                    text: "No matches"
                    color: sm.pal.text2
                }
            }
        }

        // ---- home: pinned and recommended ----
        Item {
            visible: !sm.searching && sm.view === "home"
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
                        AppTile {}
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
            Rectangle {
                visible: sm.playing
                anchors.bottom: parent.bottom
                width: parent.width
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
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
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
                text: "Recommended"
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
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
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
}
