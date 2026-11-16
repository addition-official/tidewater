// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Bell and notification center:
// one card per app (newest first), a count badge, "N more" to expand,
// Do not disturb and Clear all. History comes from Plasma's own
// notification server; Plasma still draws the pop-ups themselves.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import "common"
import "shared"
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings, shared by every Tidewater widget.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Right-click > "Tidewater settings...": opens the start button's settings
    // page, where all of Tidewater is set up (hidden without a start button).
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Tidewater settings..."
            icon.name: "configure"
            visible: Settings.canOpen
            onTriggered: Settings.openSettings()
        }
    ]
    Palette { id: design }

    NotificationManager.Settings {
        id: settings
        live: true
    }
    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() }

    readonly property bool quiet: {
        const until = settings.notificationsInhibitedUntil;
        return (until && until.getTime && until.getTime() > root.now) || settings.notificationsInhibitedByApplication;
    }
    function toggleDnd() {
        if (quiet) {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            settings.notificationsInhibitedUntil = d;
        }
        settings.save();
        root.now = Date.now();
    }

    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency
        onCountChanged: rebuild.restart()
        onDataChanged: rebuild.restart()
        Component.onCompleted: {
            ReadMark.offer(Plasmoid.configuration.lastRead);
            root.applyLastRead();
            rebuild.restart();
        }
    }
    // Read on any copy of this widget (another monitor) counts as read here.
    function applyLastRead() {
        const t = ReadMark.lastRead;
        if (!t) return;
        history.lastRead = new Date(t);
        if (Plasmoid.configuration.lastRead !== t) Plasmoid.configuration.lastRead = t;
    }
    Connections {
        target: ReadMark
        function onLastReadChanged() { root.applyLastRead(); }
    }
    readonly property int unseen: history.unreadNotificationsCount

    // Notification bodies may carry a little HTML: keep the text, line breaks
    // and the common entities (shown as plain text, never rendered).
    function plainBody(html) {
        return String(html || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'").replace(/&nbsp;/g, " ")
            .replace(/&amp;/g, "&");
    }

    // Which app groups the user has opened. Kept here, not in the cards, because
    // the cards are rebuilt whenever a notification arrives.
    property var openGroups: ({})
    function setGroupOpen(app, open) {
        const m = Object.assign({}, openGroups);
        if (open) m[app] = true; else delete m[app];
        openGroups = m;
    }

    // Plasma's model is flat; group it by application here, newest first.
    property var groups: []
    Timer { id: rebuild; interval: 50; onTriggered: root.regroup() }
    function regroup() {
        const R = NotificationManager.Notifications;
        const byApp = {};
        const order = [];
        for (let i = 0; i < history.count; ++i) {
            const idx = history.index(i, 0);
            const app = history.data(idx, R.ApplicationNameRole) || "System";
            if (!byApp[app]) {
                byApp[app] = { app: app, icon: history.data(idx, R.ApplicationIconNameRole) || "", entries: [] };
                order.push(app);
            }
            byApp[app].entries.push({
                id: history.data(idx, R.IdRole),
                summary: history.data(idx, Qt.DisplayRole) || "",
                body: root.plainBody(history.data(idx, R.BodyRole)),
                when: history.data(idx, R.CreatedRole),
                urgency: history.data(idx, R.UrgencyRole),
                hasDefault: history.data(idx, R.HasDefaultActionRole) === true
            });
        }
        const out = order.map(a => byApp[a]);
        for (const g of out) g.entries.sort((x, y) => (y.when || 0) - (x.when || 0));
        out.sort((x, y) => (y.entries[0].when || 0) - (x.entries[0].when || 0));
        groups = out;
    }

    // Rows move as notifications arrive, so act on a notification by its id.
    function rowOf(id) {
        for (let i = 0; i < history.count; ++i) {
            const idx = history.index(i, 0);
            if (history.data(idx, NotificationManager.Notifications.IdRole) === id) return idx;
        }
        return null;
    }
    function invoke(id) { const idx = rowOf(id); if (idx) history.invokeDefaultAction(idx); }
    function dismiss(id) { const idx = rowOf(id); if (idx) history.close(idx); }

    function ago(when) {
        if (!when) return "";
        const s = Math.max(0, (root.now - when.getTime()) / 1000);
        if (s < 60) return "Just now";
        if (s < 3600) return Math.floor(s / 60) + " min ago";
        if (s < 86400) return Math.floor(s / 3600) + " h ago";
        const d = Math.floor(s / 86400);
        return d === 1 ? "Yesterday" : d + " days ago";
    }
    function dismissGroup(entries) {
        for (const e of entries) root.dismiss(e.id);
    }
    function clearAll() {
        history.clear(NotificationManager.Notifications.ClearExpired);
        for (let i = history.count - 1; i >= 0; --i) history.close(history.index(i, 0));
    }

    // root.expanded, not the signal's injected "expanded" (deprecated in Qt 6)
    onExpandedChanged: {
        if (root.expanded) {
            root.now = Date.now();
        } else {
            ReadMark.lastRead = new Date().toISOString();
        }
    }

    toolTipMainText: "Notifications"
    toolTipSubText: quiet ? "Do not disturb is on" : unseen > 0 ? unseen + " unread" : "No new notifications"

    // ---- the bell -------------------------------------------------------------
    compactRepresentation: Item {
        Layout.minimumWidth: bell.implicitWidth
        Layout.preferredWidth: bell.implicitWidth
        Layout.maximumWidth: bell.implicitWidth
        Layout.fillHeight: true
        BarButton {
            buttons: Qt.LeftButton | Qt.MiddleButton   // middle-click: do not disturb
            id: bell
            anchors.centerIn: parent
            pal: design
            size: Math.max(22, Math.round(40 * design.unit))
            active: root.expanded
            glyph: root.quiet ? "notifications_off" : "notifications"
            fallback: "notifications"
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) root.toggleDnd();
                else root.expanded = !root.expanded;
            }
            Rectangle {
                visible: root.unseen > 0 && !root.expanded && !root.quiet
                x: bell.width - width - Math.round(bell.width * 0.08)
                y: Math.round(bell.height * 0.08)
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: "#e0393e"        // red, like the unread badges on the taskbar
                border.width: 2
                border.color: Kirigami.Theme.backgroundColor
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.unseen > 99 ? "99+" : String(root.unseen)
                    color: "white"
                    font.family: design.font
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    // ---- the center -------------------------------------------------------------
    // In the manner of Windows 11: notifications grouped under their app's
    // name and icon, one card each (newest first), two per app until "Show
    // more"; Do not disturb and Clear all at the top.

    // A small icon button, framed only while hovered (or while `on`).
    component IconBtn: Rectangle {
        id: ib
        property string glyph
        property string fallback
        property string tip
        property bool on: false
        property int glyphSize: 20
        signal clicked()
        implicitWidth: 32
        implicitHeight: 32
        radius: 6
        color: on ? design.blue : ibArea.containsMouse ? design.tintHover : "transparent"
        Glyph {
            anchors.centerIn: parent
            name: ib.glyph; fallback: ib.fallback
            size: ib.glyphSize; wght: 300
            filled: ib.on
            color: ib.on ? design.blueText : design.text1
            fontAvailable: design.hasIconFont
        }
        MouseArea {
            id: ibArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
        QQC2.ToolTip.visible: ibArea.containsMouse && ib.tip !== ""
        QQC2.ToolTip.text: ib.tip
        QQC2.ToolTip.delay: 500
    }

    // One notification.
    component NoteCard: Rectangle {
        id: note
        required property var entry
        width: parent ? parent.width : 0
        height: texts.implicitHeight + 24
        radius: 8
        color: noteArea.containsMouse ? design.tintHover : design.tint
        border.width: 1
        border.color: design.stroke
        MouseArea {
            id: noteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: note.entry.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (note.entry.hasDefault) root.invoke(note.entry.id)
        }
        Column {
            id: texts
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 3
            Item {
                width: parent.width
                height: Math.max(title.implicitHeight, 18)
                Text {
                    id: title
                    width: parent.width - when.width - 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: note.entry.summary
                    textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                    font.family: design.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: note.entry.urgency === NotificationManager.Notifications.CriticalUrgency ? design.danger : design.text1
                }
                // the time; a close button in its place while hovered
                Text {
                    id: when
                    visible: !noteArea.containsMouse && !closeBtn.hovered
                    anchors.right: parent.right
                    text: root.ago(note.entry.when)
                    font.family: design.font
                    font.pixelSize: 11
                    color: design.text3
                }
                IconBtn {
                    id: closeBtn
                    readonly property bool hovered: closeHover.hovered
                    visible: noteArea.containsMouse || hovered
                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    anchors.top: parent.top
                    anchors.topMargin: -7
                    width: 28
                    height: 28
                    glyph: "close"; fallback: "window-close"; glyphSize: 16
                    tip: "Dismiss"
                    onClicked: root.dismiss(note.entry.id)
                    HoverHandler { id: closeHover }
                }
            }
            Text {
                visible: text.length > 0
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                text: note.entry.body
                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                font.family: design.font
                font.pixelSize: 12
                color: design.text2
            }
        }
    }

    // An app's notifications: its name and icon, then its cards.
    component AppGroup: Column {
        id: group
        required property var modelData
        readonly property var entries: modelData.entries
        readonly property bool open: !!root.openGroups[modelData.app]
        readonly property int shown: open ? Math.min(8, entries.length) : Math.min(2, entries.length)
        width: parent ? parent.width : 0
        spacing: 6

        Item {
            width: parent.width
            height: 26
            HoverHandler { id: headHover }
            Row {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: group.modelData.icon || "preferences-desktop-notification"
                    fallback: "preferences-desktop-notification"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.app
                    textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                    font.family: design.font
                    font.pixelSize: 12
                    color: design.text2
                }
            }
            // clear this app's notifications (shown while hovering its name)
            IconBtn {
                visible: headHover.hovered
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                glyph: "close"; fallback: "window-close"; glyphSize: 16
                tip: "Clear " + group.modelData.app
                onClicked: root.dismissGroup(group.entries)
            }
        }

        Repeater {
            model: group.entries.slice(0, group.shown)
            NoteCard {
                required property var modelData
                entry: modelData
            }
        }

        Text {
            visible: group.entries.length > 2
            leftPadding: 4
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: group.open ? "Show less" : "Show " + (group.entries.length - 2) + " more"
            font.family: design.font
            font.pixelSize: 12
            color: moreArea.containsMouse ? Qt.lighter(design.blue, 1.15) : design.blue
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setGroupOpen(group.modelData.app, !group.open)
            }
        }
    }

    fullRepresentation: Item {
        FloatingPopup {}
        Layout.preferredWidth: 380
        Layout.minimumWidth: 380
        Layout.maximumWidth: 380
        Layout.preferredHeight: center.implicitHeight + 36
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        Column {
            id: center
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            Item {
                width: parent.width
                height: 32
                Text {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    font.family: design.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: design.text1
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    IconBtn {
                        glyph: "notifications_off"; fallback: "notifications-disabled"
                        on: root.quiet
                        tip: root.quiet ? "Turn off Do not disturb" : "Do not disturb"
                        onClicked: root.toggleDnd()
                    }
                    Rectangle {
                        visible: history.count > 0
                        width: clearText.implicitWidth + 22
                        height: 32
                        radius: 6
                        color: clearArea.containsMouse ? design.tintHover : design.tint
                        border.width: 1
                        border.color: design.stroke
                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear all"
                            font.family: design.font
                            font.pixelSize: 12
                            color: design.text1
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }
            }

            Flickable {
                visible: root.groups.length > 0
                width: parent.width
                height: Math.min(contentHeight, 520)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                Column {
                    id: list
                    width: parent.width
                    spacing: 14
                    Repeater {
                        model: root.groups
                        AppGroup {}
                    }
                }
            }

            Column {
                visible: root.groups.length === 0
                width: parent.width
                topPadding: 28
                bottomPadding: 28
                spacing: 10
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.quiet ? "notifications_off" : "notifications"
                    fallback: "notifications"
                    size: 32; wght: 300
                    color: design.text3
                    fontAvailable: design.hasIconFont
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.quiet ? "Do not disturb is on" : "No new notifications"
                    font.family: design.font
                    font.pixelSize: 13
                    color: design.text2
                }
            }
        }
    }
}
