// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Put inside a popup's content (start menu, quick settings, calendar,
// notifications): the popup then floats a little away from the panel and
// from the screen edges, like Windows 11, instead of touching them.
//
// Plasma does this itself only when the panel is set to "Floating: Applets
// only" (with a smaller gap). Its popup window has a `margin` for it; this
// sets that margin, and sets it again if Plasma changes it back.
import QtQuick

Item {
    id: f
    property int gap: 12
    visible: false
    readonly property var win: Window.window
    function apply() {
        if (f.win && f.win.margin !== undefined && f.win.margin !== f.gap)
            f.win.margin = f.gap;
    }
    onWinChanged: apply()
    Component.onCompleted: apply()
    Connections {
        target: f.win
        ignoreUnknownSignals: true
        function onMarginChanged() { f.apply(); }
    }
}
