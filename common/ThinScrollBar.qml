// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A scroll bar in the manner of Windows 11: no arrows and no track, just a
// thin rounded bar at the edge that widens while you hover or drag it, and
// is only there when there is something to scroll.
import QtQuick
import QtQuick.Controls.Basic as B

B.ScrollBar {
    id: bar
    property color tint: "#888888"     // usually the palette's text2
    readonly property bool wide: hovered || pressed
    policy: B.ScrollBar.AsNeeded
    padding: 2
    minimumSize: 0.08
    background: null
    contentItem: Rectangle {
        implicitWidth: bar.wide ? 6 : 3
        implicitHeight: bar.wide ? 6 : 3
        radius: width / 2
        color: bar.tint
        opacity: bar.size < 1 ? (bar.wide ? 0.8 : 0.5) : 0
        Behavior on implicitWidth { NumberAnimation { duration: 100 } }
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
}
