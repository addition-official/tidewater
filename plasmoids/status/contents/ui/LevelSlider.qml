// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Level slider in the manner of Windows 11: a thin track, a round handle
// with an accent dot, and the number in a small bubble above the handle
// while it is dragged or hovered.
import QtQuick
import QtQuick.Controls.Basic as B

Item {
    id: root
    required property var pal
    property real value: 0
    property real from: 0
    property real to: 100
    readonly property bool pressed: slider.pressed
    signal moved(real value)
    implicitHeight: 24
    function set(v) { if (!slider.pressed) slider.value = v; }

    B.Slider {
        id: slider
        anchors.fill: parent
        from: root.from
        to: root.to
        stepSize: 1
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: root.pal.alpha(root.pal.text1, 0.18)
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.pal.blue
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 20
            height: 20
            radius: 10
            color: root.pal.dark ? "#3a3b42" : "#ffffff"
            border.width: 1
            border.color: root.pal.stroke
            Rectangle {
                anchors.centerIn: parent
                width: slider.pressed ? 8 : slider.hovered ? 12 : 10
                height: width
                radius: width / 2
                color: root.pal.blue
                Behavior on width { NumberAnimation { duration: 90 } }
            }
            // the level, above the handle while it is dragged or hovered
            Rectangle {
                visible: slider.pressed || slider.hovered
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(30, bubble.implicitWidth + 14)
                height: 24
                radius: 4
                color: root.pal.dark ? "#2c2d33" : "#ffffff"
                border.width: 1
                border.color: root.pal.stroke
                Text {
                    id: bubble
                    anchors.centerIn: parent
                    text: Math.round(slider.value)
                    font.family: root.pal.font
                    font.pixelSize: 12
                    color: root.pal.text1
                }
            }
        }
    }
}
