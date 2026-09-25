// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Search pill -- part of Tidewater.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Palette { id: design }
    Exec { id: exec }
    fullRepresentation: Item {}
    toolTipMainText: "Search"

    compactRepresentation: Item {
        Layout.minimumWidth: item.implicitWidth
        Layout.preferredWidth: item.implicitWidth
        Layout.maximumWidth: item.implicitWidth
        Layout.fillHeight: true
        BarButton {
            id: item
            anchors.centerIn: parent
            pal: design
            filled: true
            glyph: "search"
            fallback: "search"
            text: "Search"
            onClicked: exec.run("busctl --user call org.kde.krunner /App org.kde.krunner.App display")
        }
    }
}
