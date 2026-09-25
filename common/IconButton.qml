// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Round icon button (34px, glyph at 56%).
import QtQuick


Item {
    id: b
    required property var pal
    property string glyph
    property string fallback
    property real size: 34
    property color color: pal.fg
    property string tip
    signal clicked()
    implicitWidth: size
    implicitHeight: size
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: area.containsMouse ? b.pal.alpha(b.pal.fg, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    Glyph {
        anchors.centerIn: parent
        name: b.glyph
        fallback: b.fallback
        size: Math.round(b.size * 0.56)
        color: b.color
        fontAvailable: b.pal.hasIconFont
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
