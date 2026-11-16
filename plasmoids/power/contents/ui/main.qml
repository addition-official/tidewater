// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Power button and the optional show desktop corner -- part of Tidewater.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"
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
    Exec { id: exec }
    fullRepresentation: Item {}
    // over the show desktop corner the tooltip says what that does
    property bool cornerHovered: false
    toolTipMainText: cornerHovered ? "Show desktop" : (Settings.showPower ? "Power" : "")

    compactRepresentation: Item {
        id: box
        // Hidden in Tidewater's settings: no size and nothing drawn, so the
        // panel closes up around it (Plasma's own Remove still works too).
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.showPower
        readonly property bool corner: Settings.showDesktopCorner
        // the corner's own sliver, kept whether the corner is on or off, so
        // turning it on or off never moves anything
        readonly property int gap: Math.max(6, Math.round(8 * design.unit))
        readonly property int w: row.implicitWidth + gap
        Layout.minimumWidth: w
        Layout.preferredWidth: w
        Layout.maximumWidth: w
        Layout.fillHeight: true

        Row {
            id: row
            height: parent.height
            spacing: 0

            Item {
                width: box.shown ? item.implicitWidth : 0
                height: parent.height
                BarButton {
                    id: item
                    visible: box.shown
                    anchors.centerIn: parent
                    pal: design
                    size: Math.max(22, Math.round(40 * design.unit))
                    glyph: "power_settings_new"
                    fallback: "system-shutdown-symbolic"
                    onClicked: exec.run("busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptAll")
                }
            }

        }

        // Show desktop corner, like Windows: a thin sliver at the far right
        // end of the taskbar; a thin line shows while you hover it. The
        // sliver is always there (empty while the corner is off); while on,
        // its area also reaches over any space left up to the panel's edge.
        // Click: show the desktop; click again: the windows come back
        // (KWin's own "Show Desktop" toggle).
        Item {
            id: corner
            visible: box.corner
            x: row.implicitWidth
            width: box.gap
            height: parent.height
            property int reach: box.gap
            function measure() {
                const win = corner.Window.window;
                if (!win)
                    return;
                const right = win.width - corner.mapToItem(null, 0, 0).x;
                corner.reach = Math.max(box.gap, Math.min(48, Math.round(right)));
            }
            Component.onCompleted: Qt.callLater(measure)
            onVisibleChanged: if (visible) Qt.callLater(measure)
            onXChanged: Qt.callLater(measure)
            // the panel can still be settling into place: look again now and then
            Timer {
                interval: 2000
                running: corner.visible
                repeat: true
                onTriggered: corner.measure()
            }
            Rectangle {
                x: Math.round(corner.reach / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Math.round(parent.height * 0.42)
                color: design.text2
                opacity: cornerArea.containsMouse ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
            MouseArea {
                id: cornerArea
                x: 0
                width: corner.reach
                height: parent.height
                hoverEnabled: true
                onContainsMouseChanged: root.cornerHovered = containsMouse
                onClicked: exec.run("busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s 'Show Desktop'", true)
            }
        }
    }
}
