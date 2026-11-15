// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A quick settings button, in the manner of Windows 11: a 48px button with
// the icon (click to switch on or off), and when there is a settings page,
// an arrow part on its right that opens it. The name and the state are
// written under the button. Filled with the accent color while on.
import QtQuick
import QtQuick.Layouts
import "common"

Item {
    id: tile
    required property var pal
    property string title
    property string subtitle
    property string glyph
    property string fallback
    property string svg               // a drawing in Glyph.qml, used instead of `glyph`
    property bool on: false
    property bool available: true
    property bool hasPage: false
    signal toggled()
    signal pageRequested()

    readonly property color ink: on ? pal.blueText : pal.text1

    Layout.fillWidth: true
    implicitHeight: button.height + 7 + labels.implicitHeight
    opacity: available ? 1 : 0.5

    Rectangle {
        id: button
        width: parent.width
        height: 48
        radius: 8
        color: tile.on ? (mainArea.containsMouse && tile.available ? Qt.lighter(tile.pal.blue, tile.pal.dark ? 1.08 : 1.12) : tile.pal.blue)
                       : (mainArea.containsMouse && tile.available ? tile.pal.tintHover : tile.pal.tint)
        border.width: tile.on ? 0 : 1
        border.color: tile.pal.stroke
        Behavior on color { ColorAnimation { duration: 120 } }

        // the switch part: the whole button, or the part left of the arrow
        Item {
            id: mainPart
            width: tile.hasPage ? parent.width - pagePart.width : parent.width
            height: parent.height
            Glyph {
                anchors.centerIn: parent
                name: tile.glyph
                fallback: tile.fallback
                svg: tile.svg
                size: 20
                wght: 300
                filled: tile.on
                color: tile.ink
                fontAvailable: tile.pal.hasIconFont
            }
            MouseArea {
                id: mainArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (tile.available) tile.toggled()
            }
        }

        // the arrow part: opens the settings page
        Item {
            id: pagePart
            visible: tile.hasPage
            anchors.right: parent.right
            width: 34
            height: parent.height
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 6
                color: tile.pal.alpha(tile.ink, pageArea.containsMouse ? 0.12 : 0)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 24
                color: tile.pal.alpha(tile.ink, tile.on ? 0.25 : 0.12)
            }
            Glyph {
                anchors.centerIn: parent
                name: "chevron_right"
                fallback: "go-next-symbolic"
                size: 18
                wght: 300
                color: tile.ink
                fontAvailable: tile.pal.hasIconFont
            }
            MouseArea {
                id: pageArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.pageRequested()
            }
        }
    }

    Column {
        id: labels
        anchors.top: button.bottom
        anchors.topMargin: 7
        width: parent.width
        spacing: 1
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.title
            font.family: tile.pal.font
            font.pixelSize: 12
            color: tile.pal.text1
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.subtitle
            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
            font.family: tile.pal.font
            font.pixelSize: 11
            color: tile.pal.text2
        }
    }
}
