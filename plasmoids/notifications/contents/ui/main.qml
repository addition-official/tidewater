// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Notification bell (optional): the notifications are in the clock's popup,
// like Windows 11, so this bell is hidden unless "Show a separate
// notification bell" is on in Tidewater's settings. It shows the same
// notifications (common/NotificationData.qml, NotificationPanel.qml), and
// reading them here or in the clock counts everywhere (ReadMark).
// Plasma still draws the pop-ups themselves.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings and the shared read state, for every Tidewater widget.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    // Turned off in Tidewater's settings: hidden from the panel altogether
    // (a widget with no size still gets the panel's gap on each side)
    Plasmoid.status: Settings.showBell ? PlasmaCore.Types.PassiveStatus : PlasmaCore.Types.HiddenStatus
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

    NotificationData {
        id: notifs
        lastRead: ReadMark.lastRead
    }
    Connections {
        target: ReadMark
        function onLastReadChanged() {
            if (Plasmoid.configuration.lastRead !== ReadMark.lastRead)
                Plasmoid.configuration.lastRead = ReadMark.lastRead;
        }
    }
    Component.onCompleted: ReadMark.offer(Plasmoid.configuration.lastRead)
    // closing the popup marks everything shown in it as read
    onExpandedChanged: if (!root.expanded) ReadMark.offer(notifs.markRead())

    toolTipMainText: Settings.showBell ? "Notifications" : ""
    toolTipSubText: !Settings.showBell ? "" : notifs.quiet ? "Do not disturb is on"
        : notifs.unseen > 0 ? notifs.unseen + " unread" : "No new notifications"

    // ---- the bell (hidden unless turned on) -------------------------------------
    compactRepresentation: Item {
        // Hidden: no size and nothing drawn, so the panel closes up around it.
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.showBell
        Layout.minimumWidth: shown ? bell.implicitWidth : 0
        Layout.preferredWidth: shown ? bell.implicitWidth : 0
        Layout.maximumWidth: shown ? bell.implicitWidth : 0
        Layout.fillHeight: true
        BarButton {
            id: bell
            visible: parent.shown
            buttons: Qt.LeftButton | Qt.MiddleButton   // middle-click: do not disturb
            anchors.centerIn: parent
            pal: design
            size: Math.max(22, Math.round(40 * design.unit))
            active: root.expanded
            glyph: notifs.quiet ? "notifications_off" : "notifications"
            svg: notifs.quiet ? "snooze" : "bell"
            fallback: "notifications"
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) notifs.toggleDnd();
                else root.expanded = !root.expanded;
            }
            Rectangle {
                visible: notifs.unseen > 0 && !root.expanded && !notifs.quiet
                x: bell.width - width - Math.round(bell.width * 0.08)
                y: Math.round(bell.height * 0.08)
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: "#e0393e"        // red, like the unread badges on the taskbar
                border.width: 2
                border.color: design.surface
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: notifs.unseen > 99 ? "99+" : String(notifs.unseen)
                    color: "white"
                    font.family: design.font
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    fullRepresentation: Item {
        FloatingPopup {}
        Layout.preferredWidth: 360
        Layout.minimumWidth: 360
        Layout.maximumWidth: 360
        Layout.preferredHeight: panel.implicitHeight
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        NotificationPanel {
            id: panel
            notes: notifs
            pal: design
            width: parent.width
            maxListHeight: 520
        }
    }
}
