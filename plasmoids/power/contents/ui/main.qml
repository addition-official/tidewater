// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Power button -- part of Tidewater.
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
    toolTipMainText: "Power"

    compactRepresentation: Item {
        Layout.minimumWidth: item.implicitWidth
        Layout.preferredWidth: item.implicitWidth
        Layout.maximumWidth: item.implicitWidth
        Layout.fillHeight: true
        BarButton {
            id: item
            anchors.centerIn: parent
            pal: design
            size: Math.max(22, Math.round(40 * design.unit))
            glyph: "power_settings_new"
            fallback: "system-shutdown-symbolic"
            onClicked: exec.run("busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptAll")
        }
    }
}
