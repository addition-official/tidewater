// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Divider -- part of Tidewater.
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
    toolTipMainText: ""

    compactRepresentation: Item {
        Layout.minimumWidth: item.implicitWidth
        Layout.preferredWidth: item.implicitWidth
        Layout.maximumWidth: item.implicitWidth
        Layout.fillHeight: true
        Item {
            id: item
            implicitWidth: 9
            anchors.fill: parent
            Divider { anchors.centerIn: parent; pal: design }
        }
    }
}
