// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The search panel, in the manner of Windows 11: shown above the taskbar's
// search box, and in the start menu while you type. Filter tabs on top (All,
// Apps, Documents, Folders, Settings). Before you
// type: Recent files on the left, Top apps (your pinned apps) on the right.
// While you type: the Best match, then the rest grouped by kind on the left,
// and on the right the details of the selected result with what you can do
// with it (Open, the app's own actions, pin, open the file's folder).
// No web results. The search itself is the start widget's (box.owner).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: panel
    required property var box      // the search box (main.qml): owner, query, results, selected...
    required property var pal
    width: 760
    height: 600
    // the details pane (and Top apps) on the right; the list fills the rest
    readonly property int detailW: Math.min(312, Math.round(width * 0.41))
    readonly property int listW: width - detailW - 48

    readonly property var owner: box.owner
    readonly property bool searching: box.query.trim().length > 0
    readonly property var current: box.results.length > 0 ? box.results[Math.min(box.selected, box.results.length - 1)] : null

    readonly property var tabs: [
        { id: "all", label: "All" },
        { id: "apps", label: "Apps" },
        { id: "documents", label: "Documents" },
        { id: "folders", label: "Folders" },
        { id: "settings", label: "Settings" }
    ]
    function kindLabel(item) {
        if (!item) return "";
        if (item.kind === "app") return "Apps";
        if (item.kind === "setting") return "Settings";
        if (item.kind === "file") return item.folder ? "Folders" : "Documents";
        return "Actions";
    }
    function typeLabel(item) {
        if (!item) return "";
        if (item.kind === "app") return "App";
        if (item.kind === "setting") return "System Settings";
        if (item.kind === "file") return item.folder ? "Folder" : "Document";
        return "Action";
    }
    function done() { box.stopTyping(); }
    // one of the details pane's choices
    function run(c) {
        const o = owner, it = current;
        if (!o || !c) return;
        if (c.what === "launch") o.launch(c.arg);
        else if (c.what === "action") o.launchAction(it.id, c.arg);
        else if (c.what === "pin") o.togglePin(c.arg);
        else if (c.what === "taskbar") o.toggleTaskbar(c.arg);
        else if (c.what === "open") o.openUrl(c.arg);
        else if (c.what === "session") o.session(c.arg);
        if (!c.keepOpen) done();    // pinning keeps the panel open
    }

    component Label: Text {
        property bool strong: false
        font.family: panel.pal.font
        font.pixelSize: 13
        font.weight: strong ? Font.DemiBold : Font.Normal
        color: panel.pal.text1
        elide: Text.ElideRight
        textFormat: Text.PlainText   // app/file names: never render as HTML
    }
    component ItemIcon: Item {
        property var item
        Kirigami.Icon {
            anchors.fill: parent
            visible: !!parent.item && parent.item.kind !== "action"
            source: parent.item ? (parent.item.icon || (parent.item.kind === "app" ? "application-x-executable"
                                  : parent.item.folder ? "folder" : "text-x-generic")) : ""
            fallback: parent.item && parent.item.kind === "app" ? "application-x-executable" : "text-x-generic"
        }
        Glyph {
            anchors.centerIn: parent
            visible: !!parent.item && parent.item.kind === "action"
            name: parent.item ? (parent.item.glyph || "") : ""
            size: Math.round(parent.width * 0.75); wght: 300
            color: panel.pal.text1
            fontAvailable: panel.pal.hasIconFont
        }
    }

    // ---- filter tabs ----
    Row {
        x: 20
        y: 16
        spacing: 6
        Repeater {
            model: panel.tabs
            Rectangle {
                id: tabChip
                required property var modelData
                readonly property bool current: panel.box.tab === modelData.id
                width: tabText.implicitWidth + 24
                height: 30
                radius: 15
                color: current ? panel.pal.tintHover : tabArea.containsMouse ? panel.pal.tint : "transparent"
                Label {
                    id: tabText
                    anchors.centerIn: parent
                    text: tabChip.modelData.label
                    font.pixelSize: 12
                    strong: tabChip.current
                }
                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.box.tab = tabChip.modelData.id
                }
            }
        }
    }
    Rectangle { y: 58; width: parent.width; height: 1; color: panel.pal.divider }

    // ---- before typing: Recent, and Top apps ----
    Item {
        visible: !panel.searching
        y: 59
        width: parent.width
        height: parent.height - 59
        Label { x: 24; y: 18; text: "Recent"; strong: true; font.pixelSize: 14 }
        Column {
            x: 16
            y: 50
            width: panel.listW
            spacing: 2
            Repeater {
                model: panel.owner ? panel.owner.recent.slice(0, 8) : []
                Rectangle {
                    id: recentRow
                    required property var modelData
                    width: panel.listW
                    height: 52
                    radius: 8
                    color: recentArea.containsMouse ? panel.pal.tintHover : "transparent"
                    ItemIcon {
                        id: recentIcon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32
                        item: ({ kind: "file", icon: recentRow.modelData.icon, folder: recentRow.modelData.folder })
                    }
                    Column {
                        anchors.left: recentIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Label { width: parent.width; text: recentRow.modelData.name }
                        Label {
                            width: parent.width
                            text: panel.owner ? panel.owner.fileWhere(recentRow.modelData) : ""
                            font.pixelSize: 12
                            color: panel.pal.text2
                        }
                    }
                    MouseArea {
                        id: recentArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.owner.openUrl(recentRow.modelData.url); panel.done(); }
                    }
                }
            }
            Label {
                visible: !panel.owner || panel.owner.recent.length === 0
                leftPadding: 8
                topPadding: 8
                text: "Files you open will show up here."
                color: panel.pal.text2
            }
        }
        Rectangle {
            x: panel.listW + 32
            y: 14
            width: panel.detailW
            height: parent.height - 30
            radius: 8
            color: panel.pal.tint
            border.width: 1
            border.color: panel.pal.stroke
            Label { x: 16; y: 16; text: "Top apps"; strong: true; font.pixelSize: 14 }
            Grid {
                x: 8
                y: 50
                columns: 3
                Repeater {
                    model: panel.owner ? panel.owner.pinnedApps.slice(0, 9) : []
                    Item {
                        id: topApp
                        required property var modelData
                        width: Math.floor((panel.detailW - 18) / 3)
                        height: 86
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 8
                            color: topArea.containsMouse ? panel.pal.tintHover : "transparent"
                        }
                        Kirigami.Icon {
                            id: topIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 14
                            width: 32; height: 32
                            source: topApp.modelData.icon || "application-x-executable"
                            fallback: "application-x-executable"
                        }
                        Label {
                            anchors.top: topIcon.bottom
                            anchors.topMargin: 9
                            x: 4
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: topApp.modelData.name
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: topArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.owner.launch(topApp.modelData.id); panel.done(); }
                        }
                    }
                }
            }
        }
    }

    // ---- while typing: results on the left, details on the right ----
    Item {
        visible: panel.searching
        y: 59
        width: parent.width
        height: parent.height - 59

        Flickable {
            x: 16
            y: 14
            width: panel.listW + 4
            height: parent.height - 28
            contentHeight: resultsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            Column {
                id: resultsCol
                width: panel.listW
                spacing: 2
                Repeater {
                    model: panel.box.results
                    Column {
                        id: entry
                        required property var modelData
                        required property int index
                        width: panel.listW
                        readonly property bool best: index === 0
                        readonly property bool firstOfGroup: index === 1 || (index > 1 && panel.kindLabel(panel.box.results[index - 1]) !== panel.kindLabel(modelData))
                        readonly property bool isSelected: index === panel.box.selected
                        Item { visible: entry.firstOfGroup; width: 1; height: 8 }
                        Label {
                            visible: entry.best || entry.firstOfGroup
                            leftPadding: 6
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                            text: entry.best ? "Best match" : panel.kindLabel(entry.modelData)
                            font.pixelSize: 12
                            strong: true
                            color: panel.pal.text2
                        }
                        Rectangle {
                            width: panel.listW
                            height: entry.best ? 64 : 50
                            radius: 8
                            color: entry.isSelected || rowArea.containsMouse ? panel.pal.tintHover : "transparent"
                            Rectangle {
                                visible: entry.isSelected
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: 18; radius: 1.5
                                color: panel.pal.blue
                            }
                            ItemIcon {
                                id: rowIcon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: entry.best ? 36 : 28
                                height: width
                                item: entry.modelData
                            }
                            Column {
                                anchors.left: rowIcon.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Label {
                                    width: parent.width
                                    text: entry.modelData.name
                                    strong: entry.best
                                    font.pixelSize: entry.best ? 14 : 13
                                }
                                Label {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: entry.best ? panel.typeLabel(entry.modelData) : (entry.modelData.description || "")
                                    font.pixelSize: 12
                                    color: panel.pal.text2
                                }
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: panel.box.selected = entry.index
                                onClicked: panel.box.activate(entry.modelData)
                            }
                        }
                    }
                }
                Label {
                    visible: panel.box.results.length === 0
                    leftPadding: 8
                    topPadding: 8
                    text: "No matches"
                    color: panel.pal.text2
                }
            }
        }

        // details of the selected result
        Rectangle {
            visible: !!panel.current
            x: panel.listW + 32
            y: 14
            width: panel.detailW
            height: parent.height - 30
            radius: 8
            color: panel.pal.tint
            border.width: 1
            border.color: panel.pal.stroke

            readonly property var item: panel.current
            readonly property var appEntry: item && item.kind === "app" && panel.owner
                ? (panel.owner.apps.find(a => a.id === item.id) || null) : null
            // What can be done with it: { glyph, label, what, arg, keepOpen } (run by panel.run)
            readonly property var choices: {
                const it = item;
                if (!it || !panel.owner) return [];
                const o = panel.owner;
                const list = [];
                if (it.kind === "app") {
                    list.push({ glyph: "open_in_new", label: "Open", what: "launch", arg: it.id });
                    for (const a of (appEntry && appEntry.actions) || [])
                        list.push({ glyph: "play_arrow", label: a.name, what: "action", arg: a.id });
                    o.pinnedIds;   // worked out again when pins change
                    list.push({ glyph: "push_pin", label: o.isPinned(it.id) ? "Unpin from Start" : "Pin to Start", what: "pin", arg: it.id, keepOpen: true });
                    o.taskbarPins;
                    list.push({ glyph: "keep", label: o.isOnTaskbar(it.id) ? "Unpin from taskbar" : "Pin to taskbar", what: "taskbar", arg: it.id, keepOpen: true });
                } else if (it.kind === "file") {
                    list.push({ glyph: "open_in_new", label: "Open", what: "open", arg: it.url });
                    if (!it.folder) {
                        const url = String(it.url);
                        list.push({ glyph: "folder_open", label: "Open file location", what: "open", arg: url.substring(0, url.lastIndexOf("/") + 1) });
                    }
                } else if (it.kind === "setting") {
                    list.push({ glyph: "open_in_new", label: "Open", what: "launch", arg: it.id });
                } else {
                    list.push({ glyph: "play_arrow", label: it.name, what: "session", arg: it.id });
                }
                return list;
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 32
                spacing: 8
                width: parent.width - 40
                ItemIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64
                    item: panel.current
                }
                Item { width: 1; height: 4 }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.current ? panel.current.name : ""
                    strong: true
                    font.pixelSize: 18
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.typeLabel(panel.current)
                    font.pixelSize: 12
                    color: panel.pal.text2
                }
            }
            Rectangle { x: 20; y: 196; width: parent.width - 40; height: 1; color: panel.pal.divider }
            Column {
                x: 12
                y: 208
                width: parent.width - 24
                spacing: 2
                Repeater {
                    model: parent.parent.choices
                    Rectangle {
                        id: choice
                        required property var modelData
                        width: parent.width
                        height: 38
                        radius: 6
                        color: choiceArea.containsMouse ? panel.pal.tintHover : "transparent"
                        Glyph {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: choice.modelData.glyph
                            size: 18; wght: 300
                            color: panel.pal.text1
                            fontAvailable: panel.pal.hasIconFont
                        }
                        Label {
                            x: 44
                            width: parent.width - 52
                            anchors.verticalCenter: parent.verticalCenter
                            text: choice.modelData.label
                        }
                        MouseArea {
                            id: choiceArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.run(choice.modelData)
                        }
                    }
                }
            }
        }
    }
}
