// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Bar button: plain, filled (gray pill), or accent (blue),
// sized in proportion to the bar thickness.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: b
    required property var pal
    property bool active: false
    property bool filled: false
    property bool accent: false
    property bool selected: false
    // Left click only by default, so right-click still opens Plasma's own
    // widget menu (Configure, Remove...). Opt in to more buttons if handled.
    property int buttons: Qt.LeftButton
    property bool accentGlyph: false   // blue icon on a plain button (start button while closed)
    property string glyph
    property string fallback
    // An icon theme name or picture address, shown when there is no glyph.
    // Tinted: drawn in the button's colors (theme icons that support it);
    // otherwise shown in its own colors.
    property string image
    property bool imageTinted: true
    property string text
    property real size: Math.max(22, Math.round(44 * pal.unit))
    property real glyphSize: Math.max(16, Math.round(20 * pal.unit))
    readonly property bool hovered: area.containsMouse
    readonly property real padding: Math.round(14 * Math.max(0.75, pal.unit))
    readonly property color contentColor: accent ? pal.accFg : accentGlyph ? pal.acc : filled ? pal.mut : pal.fg
    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: text.length > 0 ? content.implicitWidth + 2 * padding : size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: Math.round(b.size * 0.32)
        color: b.accent ? b.pal.acc
             : b.selected ? b.pal.accC
             : b.filled ? ((b.hovered || b.active) ? b.pal.s3 : b.pal.s2)
             : (b.hovered || b.active) ? b.pal.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: b.accent
            color: b.pal.alpha(b.pal.accFg, b.active ? 0.16 : b.hovered ? 0.08 : 0)
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(10 * Math.max(0.7, b.pal.unit))
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.glyph.length > 0
            name: b.glyph
            fallback: b.fallback
            size: b.glyphSize
            color: b.contentColor
            fontAvailable: b.pal.hasIconFont
        }
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.glyph.length === 0 && b.image.length > 0
            width: Math.round(b.glyphSize * 1.15)
            height: width
            source: b.image
            color: b.imageTinted ? b.contentColor : "transparent"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: b.text.length > 0
            text: b.text
            font.family: b.pal.font
            font.pixelSize: Math.max(12, Math.round(14 * Math.min(1, Math.max(0.85, b.pal.unit))))
            color: b.contentColor
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // buttons: Qt.NoButton makes it just a picture (e.g. a preview):
        // no hover highlight, no hand cursor
        enabled: b.buttons !== Qt.NoButton
        hoverEnabled: true
        // set explicitly: a disabled MouseArea still applies its cursor
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: b.buttons
        onClicked: mouse => b.clicked(mouse)
        onWheel: wheel => b.wheel(wheel)
    }
}
