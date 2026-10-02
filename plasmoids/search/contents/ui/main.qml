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
        Layout.minimumWidth: shown ? item.implicitWidth : 0
        Layout.preferredWidth: shown ? item.implicitWidth : 0
        Layout.maximumWidth: shown ? item.implicitWidth : 0
        Layout.fillHeight: true
        BarButton {
            id: item
            visible: parent.shown
            anchors.centerIn: parent
            pal: design
            filled: true
            glyph: "search"
            fallback: "search"
            // "full": the icon and "Search"; "icon": just the icon
            text: Settings.searchStyle === "full" ? "Search" : ""
            onClicked: exec.run("busctl --user call org.kde.krunner /App org.kde.krunner.App display")
        }
    }
}
