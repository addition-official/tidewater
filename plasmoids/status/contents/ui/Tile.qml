// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A quick-settings tile: accent-filled while on,
// grey while off, Material glyph, 14px title, 12px subtitle, chevron to a page.
import QtQuick
import QtQuick.Layouts
import "common"

Rectangle {
    id: tile
    required property var pal
    property string title
    property string subtitle
    property string glyph
    property string fallback
    property bool on: false
    property bool available: true
    property bool hasPage: false
    signal toggled()
    signal pageRequested()

    readonly property color ink: on ? pal.accFg : pal.fg

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 28
    radius: Math.round(20 * 8 / 28)
    opacity: available ? 1 : 0.5
    color: on ? pal.acc : (area.containsMouse && available ? pal.s3 : pal.s2)
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (tile.available) tile.toggled()
    }

    Column {
        id: column
        x: 16
        y: 14
        width: parent.width - 32

        Item {
            width: parent.width
            height: 24
            Glyph {
                name: tile.glyph
                fallback: tile.fallback
                size: 24
                color: tile.ink
                fontAvailable: tile.pal.hasIconFont
            }
            Item {
                anchors.right: parent.right
                anchors.rightMargin: -6
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                visible: tile.hasPage
                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: tile.pal.alpha(tile.ink, pageArea.containsMouse ? 0.15 : 0)
                }
                Glyph {
                    anchors.centerIn: parent
                    name: "chevron_right"
                    fallback: "go-next-symbolic"
                    size: 18
                    color: tile.ink
                    opacity: 0.8
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

        Item { width: 1; height: 14 }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: tile.title
            font.family: tile.pal.font
            font.pixelSize: 14
            font.weight: Font.Medium
            color: tile.ink
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: tile.subtitle
            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
            font.family: tile.pal.font
            font.pixelSize: 12
            color: tile.on ? tile.pal.alpha(tile.pal.accFg, 0.8) : tile.pal.mut
        }
    }
}
