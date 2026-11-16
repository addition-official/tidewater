// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Search pill -- part of Tidewater.
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
    toolTipMainText: "Search"

    compactRepresentation: Item {
        // Hidden in Tidewater's settings: no size and nothing drawn, so the
        // panel closes up around it (Plasma's own Remove still works too).
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.searchStyle !== "hidden"
        readonly property bool bar: Settings.searchStyle === "bar"
        readonly property real w: bar ? searchBar.width : item.implicitWidth
        Layout.minimumWidth: shown ? w : 0
        Layout.preferredWidth: shown ? w : 0
        Layout.maximumWidth: shown ? w : 0
        Layout.fillHeight: true
        function open() { exec.run("busctl --user call org.kde.krunner /App org.kde.krunner.App display"); }

        BarButton {
            id: item
            visible: parent.shown && !parent.bar
            anchors.centerIn: parent
            pal: design
            filled: true
            glyph: "search"
            svg: "search"     // the user's own magnifier (common/Glyph.qml)
            fallback: "search"
            // "full": the icon and "Search"; "icon": just the icon
            text: Settings.searchStyle === "full" ? "Search" : ""
            onClicked: parent.open()
        }

        // "bar": a search box like the one on the Windows taskbar
        Rectangle {
            id: searchBar
            visible: parent.shown && parent.bar
            anchors.centerIn: parent
            width: Math.round(220 * design.unit)
            height: Math.max(22, Math.round(44 * design.unit))
            radius: height / 2
            color: design.dark ? Qt.rgba(1, 1, 1, barArea.containsMouse ? 0.11 : 0.07)
                               : Qt.rgba(1, 1, 1, barArea.containsMouse ? 0.95 : 0.75)
            border.width: 1
            border.color: design.stroke
            Behavior on color { ColorAnimation { duration: 120 } }
            Glyph {
                id: lens
                x: Math.round(searchBar.height * 0.42)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"; svg: "search"; fallback: "search"
                size: Math.max(14, Math.round(18 * design.unit))
                color: design.fg
                fontAvailable: design.hasIconFont
            }
            Text {
                anchors.left: lens.right
                anchors.leftMargin: Math.round(10 * design.unit)
                anchors.verticalCenter: parent.verticalCenter
                text: "Search"
                font.family: design.font
                font.pixelSize: Math.max(12, Math.round(14 * Math.min(1, Math.max(0.85, design.unit))))
                color: design.mut
            }
            MouseArea {
                id: barArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.open()
            }
        }
    }
}
