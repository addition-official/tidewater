// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The start menu, two panes (928 x 668):
// a category rail, search with pinned apps and recent files, and a side
// column with the user, what's playing, system meters and session buttons.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import "common"

Item {
    id: sm
    required property var app      // main.qml's root: data and actions
    required property var pal

    implicitWidth: 928
    implicitHeight: 668

    property string view: "home"   // home | everything | recent | <category id>
    property string query: ""
    property int selected: 0
    readonly property bool searching: query.trim().length > 0
    readonly property var results: app.search(query, app.fileResults)
    readonly property real rs: 8 / 28    // corner rounding (8px) over the designed 28

    function r(designed) { return Math.round(designed * rs); }

    function reset() {
        search.text = "";
        view = "home";
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
        { id: "all", glyph: "apps", label: "All apps" },
        { id: "internet", glyph: "language", label: "Internet" },
        { id: "development", glyph: "code", label: "Development" },
        { id: "multimedia", glyph: "movie", label: "Multimedia" },
        { id: "games", glyph: "sports_esports", label: "Games" },
        { id: "utilities", glyph: "folder", label: "Utilities and office" },
        { id: "system", glyph: "settings_applications", label: "System" }
    ]

    // ---- pieces ---------------------------------------------------------------

    component SectionLabel: Text {
        font.family: sm.pal.font
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
        color: sm.pal.mut
    }

    component Heading: Item {
        id: heading
        property string text
        property string link
        signal linked()
        width: parent ? parent.width : 0
        height: 22
        SectionLabel { anchors.verticalCenter: parent.verticalCenter; text: heading.text }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: heading.link.length > 0
            text: heading.link
            font.family: sm.pal.font
            font.pixelSize: 13
            color: sm.pal.acc
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: heading.linked() }
        }
    }

    component AppTile: Item {
        id: tile
        required property var modelData
        property bool framed: true
        width: 96
        height: 100
        Rectangle {
            anchors.fill: parent
            radius: sm.r(16)
            color: tileArea.containsMouse ? sm.pal.s2 : "transparent"
        }
        Rectangle {
            id: square
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: 52
            height: 52
            radius: sm.r(16)
            color: tile.framed ? sm.pal.accC : "transparent"
            Kirigami.Icon {
                anchors.centerIn: parent
                width: tile.framed ? 30 : 40
                height: width
                source: tile.modelData.icon || "application-x-executable"
            }
        }
        Text {
            anchors.top: square.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.modelData.name
            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
            font.family: sm.pal.font
            font.pixelSize: 12
            color: sm.pal.fg
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
    }

    component ResultRow: Rectangle {
        id: result
        required property var modelData
        required property int index
        readonly property bool isSelected: result.index === sm.selected
        width: parent ? parent.width : 0
        height: 52
        radius: sm.r(14)
        color: isSelected ? sm.pal.accC : (resultArea.containsMouse ? sm.pal.s2 : "transparent")
        Item {
            id: resultIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            Kirigami.Icon {
                anchors.fill: parent
                visible: result.modelData.kind === "app"
                source: result.modelData.icon || ""
            }
            Glyph {
                anchors.centerIn: parent
                visible: result.modelData.kind !== "app"
                name: result.modelData.glyph || ""
                size: 22
                color: result.isSelected ? sm.pal.acc : sm.pal.mut
                fontAvailable: sm.pal.hasIconFont
            }
        }
        Column {
            anchors.left: resultIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: result.modelData.name
                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                font.family: sm.pal.font
                font.pixelSize: 14
                font.weight: Font.Medium
                color: result.isSelected ? sm.pal.accCFg : sm.pal.fg
            }
            Text {
                visible: text.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: result.modelData.description || ""
                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                font.family: sm.pal.font
                font.pixelSize: 12
                color: result.isSelected ? sm.pal.alpha(sm.pal.accCFg, 0.75) : sm.pal.mut
            }
        }
        MouseArea {
            id: resultArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: sm.selected = result.index
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (result.modelData.kind === "app")
                        sm.showAppMenu(result.modelData, result, mouse.x, mouse.y);
                } else {
                    sm.activate(result.modelData);
                }
            }
        }
    }

    component RecentRow: Rectangle {
        id: recentRow
        required property var modelData
        width: parent ? parent.width : 0
        height: 40
        radius: sm.r(14)
        color: recentArea.containsMouse ? sm.pal.s2 : "transparent"
        Glyph {
            id: recentGlyph
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: recentRow.modelData.folder ? "folder_open" : "description"
            fallback: recentRow.modelData.folder ? "folder-open" : "text-x-generic"
            size: 20
            color: sm.pal.mut
            fontAvailable: sm.pal.hasIconFont
        }
        Text {
            anchors.left: recentGlyph.right
            anchors.leftMargin: 14
            anchors.right: recentDir.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: recentRow.modelData.name
            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
            font.family: sm.pal.font
            font.pixelSize: 14
            color: sm.pal.fg
        }
        Text {
            id: recentDir
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 200)
            elide: Text.ElideMiddle
            text: recentRow.modelData.dir
            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
            font.family: "monospace"
            font.pixelSize: 12
            color: sm.pal.mut
        }
        MouseArea {
            id: recentArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sm.app.openUrl(recentRow.modelData.url)
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

    // ---- the category rail ----------------------------------------------------

    Item {
        id: rail
        width: 78
        height: parent.height
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: sm.pal.out }

        Column {
            y: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Repeater {
                model: sm.categories
                Rectangle {
                    id: railButton
                    required property var modelData
                    readonly property bool current: (modelData.id === "all" && (sm.view === "home" || sm.view === "everything"))
                                                    || sm.view === modelData.id
                    width: 48
                    height: 48
                    radius: sm.r(16)
                    color: current ? sm.pal.acc : railArea.containsMouse ? sm.pal.s3 : "transparent"
                    Glyph {
                        anchors.centerIn: parent
                        name: railButton.modelData.glyph
                        size: railButton.current ? 24 : 22
                        color: railButton.current ? sm.pal.accFg : sm.pal.mut
                        fontAvailable: sm.pal.hasIconFont
                    }
                    MouseArea {
                        id: railArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            search.text = "";
                            sm.view = railButton.modelData.id === "all" ? "home" : railButton.modelData.id;
                        }
                    }
                    QQC2.ToolTip.visible: railArea.containsMouse
                    QQC2.ToolTip.text: modelData.label
                    QQC2.ToolTip.delay: 500
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: 48
            radius: sm.r(16)
            color: sm.view === "recent" ? sm.pal.acc : historyArea.containsMouse ? sm.pal.s3 : "transparent"
            Glyph {
                anchors.centerIn: parent
                name: "history"
                size: 22
                color: sm.view === "recent" ? sm.pal.accFg : sm.pal.mut
                fontAvailable: sm.pal.hasIconFont
            }
            MouseArea {
                id: historyArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { search.text = ""; sm.view = "recent"; }
            }
        }
    }

    // ---- the middle: search, pinned, recent -------------------------------------

    Column {
        id: middle
        x: rail.width + 24
        y: 22
        width: parent.width - rail.width - side.width - 48
        height: parent.height - 44
        spacing: 20

        Rectangle {
            width: parent.width
            height: 48
            radius: sm.r(16)
            color: "transparent"
            border.width: 1
            border.color: search.activeFocus ? sm.pal.acc : sm.pal.out

            Glyph {
                id: lens
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                fallback: "search"
                size: 20
                color: sm.pal.mut
                fontAvailable: sm.pal.hasIconFont
            }
            Rectangle {
                id: badge
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: badgeText.implicitWidth + 14
                height: 22
                radius: sm.r(6)
                color: sm.pal.s1
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "> actions"
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: sm.pal.mut
                }
            }
            QQC2.TextField {
                id: search
                anchors.left: lens.right
                anchors.leftMargin: 10
                anchors.right: badge.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                focus: true
                color: sm.pal.fg
                selectionColor: sm.pal.accC
                selectedTextColor: sm.pal.accCFg
                font.family: sm.pal.font
                font.pixelSize: 15
                background: null
                leftPadding: 2
                placeholderText: ""
                onTextChanged: {
                    sm.query = text;
                    sm.selected = 0;
                    sm.app.searchFiles(text);
                }
                Keys.onDownPressed: sm.selected = Math.min(sm.results.length - 1, sm.selected + 1)
                Keys.onUpPressed: sm.selected = Math.max(0, sm.selected - 1)
                Keys.onReturnPressed: sm.activate(sm.results[sm.selected])
                Keys.onEnterPressed: sm.activate(sm.results[sm.selected])
                Keys.onEscapePressed: {
                    if (text.length > 0) text = "";
                    else sm.app.close();
                }
            }
            Text {
                anchors.left: lens.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text.length === 0
                text: "Search apps, files and actions"
                font.family: sm.pal.font
                font.pixelSize: 15
                color: sm.pal.mut
            }
        }

        // search results
        Column {
            visible: sm.searching
            width: parent.width
            spacing: 2
            Repeater {
                model: sm.searching ? sm.results : []
                ResultRow {}
            }
            Text {
                visible: sm.results.length === 0
                topPadding: 8
                leftPadding: 12
                text: "No matches"
                font.family: sm.pal.font
                color: sm.pal.mut
            }
        }

        Flickable {
            visible: !sm.searching
            width: parent.width
            height: parent.height - 68
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 14
                readonly property var shown: sm.view === "home" ? sm.app.pinnedApps
                    : sm.view === "everything" ? sm.app.apps
                    : sm.view === "recent" ? []
                    : sm.app.inCategory(sm.view)

                Heading {
                    visible: sm.view !== "recent"
                    text: sm.view === "home" ? "Pinned"
                        : sm.view === "everything" ? "All apps"
                        : (sm.categories.find(c => c.id === sm.view) || {}).label || ""
                    link: sm.view === "home" ? "All apps" : "Back"
                    onLinked: sm.view = sm.view === "home" ? "everything" : "home"
                }
                Grid {
                    visible: sm.view !== "recent"
                    columns: 5
                    columnSpacing: (body.width - 5 * 96) / 4
                    rowSpacing: 4
                    Repeater {
                        model: body.shown
                        AppTile { framed: sm.view === "home" }
                    }
                }
                Heading {
                    visible: sm.view === "home" || sm.view === "recent"
                    text: "Recent"
                }
                Column {
                    visible: sm.view === "home" || sm.view === "recent"
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: sm.view === "recent" ? sm.app.recent : sm.app.recent.slice(0, 3)
                        RecentRow {}
                    }
                    Text {
                        visible: sm.app.recent.length === 0
                        leftPadding: 12
                        text: "No recent files."
                        font.family: sm.pal.font
                        color: sm.pal.mut
                    }
                }
            }
        }
    }

    // ---- the side column ------------------------------------------------------

    Item {
        id: side
        anchors.right: parent.right
        width: 276
        height: parent.height
        Rectangle { width: 1; height: parent.height; color: sm.pal.out }

        Column {
            x: 20
            y: 22
            width: parent.width - 40
            spacing: 14

            Item {
                width: parent.width
                height: 44
                Rectangle {
                    id: sideAvatar
                    width: 44
                    height: 44
                    radius: 22
                    color: sm.pal.accC
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        visible: !face.visible
                        text: (sm.app.stats.user || "?").charAt(0).toUpperCase()
                        font.family: sm.pal.font
                        font.pixelSize: Math.round(44 * 0.4)
                        font.weight: Font.Medium
                        color: sm.pal.accCFg
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: sm.app.stats.avatar ? "file://" + sm.app.stats.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Column {
                    anchors.left: sideAvatar.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: sm.app.stats.user || ""
                        font.family: sm.pal.font
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        color: sm.pal.fg
                    }
                    Text {
                        text: sm.app.uptimeText(sm.app.stats.uptime)
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: sm.pal.mut
                    }
                }
            }

            // now playing
            Item {
                width: parent.width
                height: player.implicitHeight + 28
                readonly property var m: sm.app.media
                readonly property bool present: !!(m && m.title)
                Column {
                    id: player
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 10
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 56
                            height: 56
                            radius: sm.r(12)
                            color: sm.pal.accC
                            clip: true
                            Image {
                                id: art
                                anchors.fill: parent
                                source: player.parent.m.art || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: !art.visible
                                name: "music_note"
                                fallback: "media-album-cover"
                                size: 26
                                color: sm.pal.accCFg
                                fontAvailable: sm.pal.hasIconFont
                            }
                        }
                        Column {
                            width: parent.width - 68
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: player.parent.present ? player.parent.m.title : "Nothing playing"
                                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                font.family: sm.pal.font
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: player.parent.present ? sm.pal.fg : sm.pal.mut
                            }
                            Text {
                                visible: text.length > 0
                                width: parent.width
                                elide: Text.ElideRight
                                text: player.parent.present ? (player.parent.m.artist || "") : ""
                                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                font.family: sm.pal.font
                                font.pixelSize: 12
                                color: sm.pal.mut
                            }
                        }
                    }
                    Row {
                        visible: player.parent.present
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        IconButton { pal: sm.pal; glyph: "skip_previous"; fallback: "media-skip-backward"; onClicked: sm.app.mediaCmd("Previous") }
                        IconButton {
                            pal: sm.pal
                            size: 40
                            glyph: player.parent.m.playing ? "pause_circle" : "play_circle"
                            fallback: player.parent.m.playing ? "media-playback-pause" : "media-playback-start"
                            color: sm.pal.acc
                            onClicked: sm.app.mediaCmd("PlayPause")
                        }
                        IconButton { pal: sm.pal; glyph: "skip_next"; fallback: "media-skip-forward"; onClicked: sm.app.mediaCmd("Next") }
                    }
                }
            }

            // system meters
            Item {
                width: parent.width
                height: meters.implicitHeight + 32
                Rectangle { width: parent.width; height: 1; color: sm.pal.out }
                Column {
                    id: meters
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 13
                    Repeater {
                        model: {
                            const s = sm.app.stats;
                            const b = sm.app.bytes;
                            return [
                                { label: s.cpuTemp > 0 ? "CPU · " + s.cpuTemp + " °C" : "CPU",
                                  value: Math.round((s.cpu || 0) * 100) + "%", fraction: s.cpu || 0, shown: true },
                                { label: "Memory", value: b(s.memUsed) + " / " + b(s.memTotal),
                                  fraction: s.memTotal > 0 ? s.memUsed / s.memTotal : 0, shown: true },
                                { label: "Storage", value: b(s.diskFree) + " free",
                                  fraction: s.diskSize > 0 ? 1 - s.diskFree / s.diskSize : 0, shown: s.diskSize > 0 },
                                { label: s.gpuTemp > 0 ? "GPU · " + s.gpuTemp + " °C" : "GPU",
                                  value: Math.round(Math.max(0, s.gpu || 0) * 100) + "%", fraction: Math.max(0, s.gpu || 0),
                                  shown: s.gpu >= 0 }
                            ].filter(m => m.shown);
                        }
                        Column {
                            id: meter
                            required property var modelData
                            width: meters.width
                            spacing: 6
                            Item {
                                width: parent.width
                                height: 16
                                Text { text: meter.modelData.label; font.family: sm.pal.font; font.pixelSize: 12; color: sm.pal.mut }
                                Text { anchors.right: parent.right; text: meter.modelData.value; font.family: sm.pal.font; font.pixelSize: 12; color: sm.pal.mut }
                            }
                            Rectangle {
                                width: parent.width
                                height: 5
                                radius: 2.5
                                color: sm.pal.alpha(sm.pal.fg, 0.12)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, meter.modelData.fraction))
                                    height: parent.height
                                    radius: parent.radius
                                    color: sm.pal.acc
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Power: the same shut down / restart / log out screen as the panel's power button
        Rectangle {
            id: powerButton
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            width: side.width - 40
            height: 44
            radius: sm.r(14)
            color: powerArea.containsMouse ? sm.pal.s3 : sm.pal.s1
            Glyph {
                anchors.centerIn: parent
                name: "power_settings_new"
                fallback: "system-shutdown"
                size: 20
                color: sm.pal.fg
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
