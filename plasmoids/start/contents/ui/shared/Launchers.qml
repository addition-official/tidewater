// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Every Tidewater start button in this Plasma session. The Meta key opens
// whichever copy Plasma picks, and a copy with no button on a visible panel
// (a leftover one, or on a switched-off monitor) would pop up at the top-left
// corner. Such a copy hands the request to one that is on screen instead.
pragma Singleton
import QtQuick

QtObject {
    property var items: []
    function add(item) { if (items.indexOf(item) < 0) items = items.concat([item]); }
    function remove(item) { items = items.filter(x => x !== item); }
    function onScreenOne(except) {
        for (const i of items)
            if (i !== except && i.onScreen()) return i;
        return null;
    }
}
