// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Bell and notification centre:
// one card per app (newest first), a count badge, "N more" to expand,
// Do not disturb and Clear all. History comes from Plasma's own
// notification server; Plasma still draws the pop-ups themselves.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import "common"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
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
            const saved = Plasmoid.configuration.lastRead;
            if (saved) lastRead = new Date(saved);
            rebuild.restart();
        }
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
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }
    function clearAll() {
        history.clear(NotificationManager.Notifications.ClearExpired);
        for (let i = history.count - 1; i >= 0; --i) history.close(history.index(i, 0));
    }

    onExpandedChanged: {
        if (expanded) {
            root.now = Date.now();
        } else {
            history.lastRead = new Date();
            Plasmoid.configuration.lastRead = new Date().toISOString();
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
                readonly property bool counting: root.unseen > 0
                visible: root.unseen > 0 && !root.expanded && !root.quiet
                x: bell.width - width - Math.round(bell.width * 0.08)
                y: Math.round(bell.height * 0.08)
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: design.acc
                border.width: 2
                border.color: design.surface
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.unseen > 99 ? "99+" : String(root.unseen)
                    color: design.accFg
                    font.family: design.font
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    // ---- the centre -------------------------------------------------------------
    component TextButton: Rectangle {
        id: tb
        property string text
        property bool filled: false
        signal clicked()
        implicitWidth: label.implicitWidth + 28
        implicitHeight: 34
        radius: Math.min(height / 2, 4)
        color: filled ? design.acc : area.containsMouse ? design.s3 : design.s2
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            id: label
            anchors.centerIn: parent
            text: tb.text
            font.family: design.font
            font.pixelSize: 13
            color: tb.filled ? design.accFg : design.fg
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
    }

    component GroupCard: Item {
        id: card
        required property var modelData
        readonly property var entries: modelData.entries
        readonly property int count: entries.length
        readonly property bool open: !!root.openGroups[modelData.app]
        readonly property bool stacked: count > 1 && !open
        width: parent ? parent.width : 0
        height: face.height + (stacked ? 8 : 0)

        // the card peeking out underneath when there is more than one
        Rectangle {
            visible: card.stacked
            x: 12
            y: face.height - 30
            width: parent.width - 24
            height: 38
            radius: 6
            color: design.s2
        }

        Rectangle {
            id: face
            width: parent.width
            height: body.implicitHeight + 28
            radius: Math.round(20 * 8 / 28)
            color: design.s1
            border.width: 1
            border.color: design.out

            Column {
                id: body
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 0

                Item {
                    width: parent.width
                    height: 20
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "notifications"
                            fallback: card.modelData.icon || "preferences-desktop-notification"
                            size: 18
                            color: design.acc
                            fontAvailable: design.hasIconFont
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.app
                            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                            font.family: design.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: design.fg
                        }
                        Rectangle {
                            visible: card.count > 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: countText.implicitWidth + 14
                            height: 18
                            radius: 3
                            color: design.accC
                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: String(card.count)
                                font.family: design.font
                                font.pixelSize: 11
                                color: design.accCFg
                            }
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ago(card.entries[0] ? card.entries[0].when : null)
                        font.family: "monospace"
                        font.pixelSize: 11
                        color: design.mut
                    }
                }

                Item { width: 1; height: 8 }

                Repeater {
                    model: card.open ? card.entries.slice(0, 8) : card.entries.slice(0, 1)
                    Column {
                        id: note
                        required property var modelData
                        required property int index
                        width: body.width
                        Item { visible: note.index > 0; width: 1; height: 8 }
                        Rectangle { visible: note.index > 0; width: parent.width; height: 1; color: design.out }
                        Item { visible: note.index > 0; width: 1; height: 8 }
                        Item {
                            width: parent.width
                            height: texts.implicitHeight
                            HoverHandler { id: noteHover }
                            Column {
                                id: texts
                                width: parent.width - 24
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    text: note.modelData.summary
                                    textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                    font.family: design.font
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: note.modelData.urgency === NotificationManager.Notifications.CriticalUrgency ? design.danger : design.fg
                                }
                                Text {
                                    visible: text.length > 0
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    text: note.modelData.body
                                    textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                    font.family: design.font
                                    font.pixelSize: 13
                                    color: design.mut
                                }
                            }
                            MouseArea {
                                id: noteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: note.modelData.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (note.modelData.hasDefault) root.invoke(note.modelData.id)
                            }
                            IconButton {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: -4
                                visible: noteHover.hovered
                                pal: design
                                size: 24
                                glyph: "close"
                                fallback: "window-close"
                                color: design.mut
                                onClicked: root.dismiss(note.modelData.id)
                            }
                        }
                    }
                }

                Item { visible: card.count > 1; width: 1; height: 12 }
                TextButton {
                    visible: card.count > 1
                    text: card.open ? "Show less" : (card.count - 1) + " more"
                    onClicked: root.setGroupOpen(card.modelData.app, !card.open)
                }
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 424
        Layout.minimumWidth: 424
        Layout.maximumWidth: 424
        Layout.preferredHeight: centre.implicitHeight + 40
        Layout.minimumHeight: Layout.preferredHeight

        Column {
            id: centre
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 14

            Item {
                width: parent.width
                height: 34
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    font.family: design.font
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: design.fg
                }
                Row {
                    anchors.right: parent.right
                    spacing: 6
                    TextButton { text: "Do not disturb"; filled: root.quiet; onClicked: root.toggleDnd() }
                    TextButton { text: "Clear all"; visible: history.count > 0; onClicked: root.clearAll() }
                }
            }

            Flickable {
                width: parent.width
                height: Math.min(contentHeight, 560)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: list
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: root.groups
                        GroupCard {}
                    }
                }
            }

            Column {
                visible: root.groups.length === 0
                width: parent.width
                topPadding: 24
                bottomPadding: 24
                spacing: 8
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.quiet ? "notifications_off" : "notifications_none"
                    fallback: "notifications"
                    size: 36
                    color: design.mut
                    fontAvailable: design.hasIconFont
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.quiet ? "Do not disturb is on" : "No notifications"
                    font.family: design.font
                    font.pixelSize: 14
                    color: design.mut
                }
            }
        }
    }
}
