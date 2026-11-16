// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Turns off Plasma's "this widget is open" line: Plasma draws it in the
// highlight color along the top of the panel above a panel widget while its
// popup is open (or it thinks so). Tidewater's widgets show their own
// highlight, like Windows, which has no such line.
// Put one inside a compactRepresentation: it finds Plasma's wrapper around
// the widget (CompactApplet.qml, which hands the line out as
// `expandedFeedback`) and hides the line for good.
import QtQuick

Item {
    id: off
    width: 0
    height: 0
    function hide() {
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
