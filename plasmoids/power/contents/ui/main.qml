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
        readonly property int w: row.implicitWidth
        Layout.minimumWidth: w
        Layout.preferredWidth: w
        Layout.maximumWidth: w
        Layout.fillHeight: true

        Row {
            id: row
            height: parent.height
            spacing: box.shown && box.corner ? Math.round(6 * design.unit) : 0

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

            // Show desktop corner, like Windows: a thin strip at the far right.
            // Click: show the desktop; click again: the windows come back
            // (KWin's own "Show Desktop" toggle).
            Item {
                visible: box.corner
                width: visible ? Math.max(8, Math.round(12 * design.unit)) : 0
                height: parent.height
                // a short line marks where it starts
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: Math.round(parent.height * 0.4)
                    color: design.out
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    radius: 3
                    color: design.s2
                    opacity: cornerArea.containsMouse ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                MouseArea {
                    id: cornerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: root.cornerHovered = containsMouse
                    onClicked: exec.run("busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s 'Show Desktop'", true)
                }
            }
        }
    }
}
