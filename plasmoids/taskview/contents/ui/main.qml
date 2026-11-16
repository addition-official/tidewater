// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Overview button -- part of Tidewater.
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
    // Turned off in Tidewater's settings: hidden from the panel altogether
    // (a widget with no size still gets the panel's gap on each side)
    Plasmoid.status: Settings.showOverview ? PlasmaCore.Types.PassiveStatus : PlasmaCore.Types.HiddenStatus
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
    toolTipMainText: "Overview"

    compactRepresentation: Item {
        // Hidden in Tidewater's settings: no size and nothing drawn, so the
        // panel closes up around it (Plasma's own Remove still works too).
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.showOverview
        Layout.minimumWidth: shown ? item.implicitWidth : 0
        Layout.preferredWidth: shown ? item.implicitWidth : 0
        Layout.maximumWidth: shown ? item.implicitWidth : 0
        Layout.fillHeight: true
        BarButton {
            id: item
            visible: parent.shown
            anchors.centerIn: parent
            pal: design
            // the user's own Task View icon, in its own colors, with a version
            // for light mode (common/taskview.svg, taskview-light.svg)
            image: Qt.resolvedUrl(design.dark ? "common/taskview.svg" : "common/taskview-light.svg")
            imageTinted: false
            // as big as the app icons beside it (a little smaller, as it is a
            // solid shape), like the Task View button on Windows
            imageSize: Math.round(Settings.iconSize * 0.8)
            onClicked: exec.run("busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component invokeShortcut s Overview")
        }
    }
}
