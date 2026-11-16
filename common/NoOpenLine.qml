// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Turns off Plasma's highlight lines over the panel, which Windows does not
// have (Tidewater's widgets show their own highlight):
// - the panel's "Panel Focus Indicator" (plasma-desktop, views/Panel.qml):
//   a line along the top of the panel, as wide as whatever in the panel has
//   the keyboard, while the panel window is active. It showed over the search
//   box while typing, over the Start button while the menu was open, and
//   stayed until another window was clicked.
// - the "this widget is open" line (CompactApplet.qml's expandedFeedback).
// Put one inside a compactRepresentation. Both lines use the theme's tab bar
// image ("widgets/tabbar"), in the color scheme's focus color.
import QtQuick

Item {
    id: off
    width: 0
    height: 0
    // the panel's focus line: near the top of the panel window (a direct
    // child of Panel.qml's root); looked for a few levels down, well above
    // the widgets' own "open" lines, which sit much deeper
    function findTabbar(item, depth) {
        for (const c of item.children) {
            if (c.imagePath === "widgets/tabbar")
                return c;
            if (depth > 1) {
                const f = findTabbar(c, depth - 1);
                if (f) return f;
            }
        }
        return null;
    }
    function hidePanelLine() {
        const w = off.Window.window;
        if (!w || !w.contentItem)
            return false;
        const line = findTabbar(w.contentItem, 3);
        if (!line)
            return false;
        line.opacity = 0;          // its visible, x and width stay Plasma's
        return true;
    }
    // this widget's own "open" line
    function hideOpenLine() {
        for (let p = off.parent; p; p = p.parent) {
            if (p.expandedFeedback !== undefined) {
                const line = p.expandedFeedback;
                if (line) {
                    line.opacity = 0;      // replaces Plasma's binding to "expanded"
                    line.visible = false;
                }
                return true;
            }
        }
        return false;
    }
    property bool panelDone: false
    property bool openDone: false
    function hide() {
        if (!panelDone) panelDone = hidePanelLine();
        if (!openDone) openDone = hideOpenLine();
        return panelDone && openDone;
    }
    // the wrapper may only take the widget in after it is made: look again
    // until it is found
    Timer {
        id: retry
        interval: 500
        repeat: true
        running: true
        property int tries: 0
        onTriggered: if (off.hide() || ++tries > 20) stop()
    }
    Component.onCompleted: if (hide()) retry.stop()
}
