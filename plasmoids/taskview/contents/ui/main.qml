// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Overview button -- part of Tidewater.
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
    toolTipMainText: "Overview"

    compactRepresentation: Item {
        Layout.minimumWidth: item.implicitWidth
        Layout.preferredWidth: item.implicitWidth
        Layout.maximumWidth: item.implicitWidth
        Layout.fillHeight: true
        BarButton {
            id: item
            anchors.centerIn: parent
            pal: design
            glyph: "grid_view"
            fallback: "view-grid-symbolic"
            onClicked: exec.run("busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s Overview")
        }
    }
}
