// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Level slider: 6px track, 18px handle, mono readout.
import QtQuick
import QtQuick.Controls.Basic as B

Row {
    id: root
    required property var pal
    property real value: 0
    property real from: 0
    property real to: 100
    readonly property bool pressed: slider.pressed
    signal moved(real value)
    spacing: 12
    function set(v) { if (!slider.pressed) slider.value = v; }

    B.Slider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - readout.width - root.spacing
        height: 22
        from: root.from
        to: root.to
        stepSize: 1
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: root.pal.alpha(root.pal.fg, 0.14)
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.pal.acc
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: root.pal.acc
            border.width: slider.pressed ? 4 : 0
            border.color: root.pal.alpha(root.pal.accFg, 0.35)
        }
    }
    Text {
        id: readout
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.value)
        color: root.pal.mut
        font.family: "monospace"
        font.pixelSize: 12
    }
}
