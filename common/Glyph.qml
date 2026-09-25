// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A Material Symbols Rounded icon, drawn from the font by name (as in
// the original design). Falls back to a Plasma icon if the font is missing.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: g
    property string name
    property string fallback
    property real size: 20
    property color color: "black"
    property bool filled: false
    property bool fontAvailable: true
    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        visible: g.fontAvailable
        text: g.name
        color: g.color
        font.family: "Material Symbols Rounded"
        font.pixelSize: g.size
        font.variableAxes: ({ "FILL": g.filled ? 1 : 0, "opsz": Math.max(20, Math.min(48, g.size)) })
        renderType: Text.QtRendering
    }
    Kirigami.Icon {
        anchors.fill: parent
        visible: !g.fontAvailable && g.fallback.length > 0
        source: g.fallback
        color: g.color
        isMask: true
    }
}
