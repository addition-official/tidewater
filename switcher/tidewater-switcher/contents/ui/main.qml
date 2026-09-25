// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Marius Gabriel Lupu (remapprShell, https://github.com/Wolffyx/remapprShell)
// SPDX-FileCopyrightText: 2026 addition-official
// Taken from remapprShell and modified for Tidewater by addition-official, 2026.
//
// Tidewater Alt+Tab, in the manner of Windows 11: one panel on the primary
// monitor, window cards in centred rows that wrap, each card an icon and
// title over a live thumbnail sized to the window's own shape. The selected
// card gets an accent ring; the card under the mouse gets an X.
//
// KWin drives this: it sets `model` and `currentIndex` while Tab is held and
// activates the current window when Alt is released.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    // ---- where: always the primary monitor ------------------------------------
    // KWin passes the *active* screen; the first in its screen order is the
    // primary. Falls back to KWin's choice if that isn't available.
    readonly property rect home: {
        try {
            const order = KWin.Workspace.screenOrder;
            const g = order && order.length > 0 ? order[0].geometry : null;
            if (g && g.width > 0)
                return Qt.rect(g.x, g.y, g.width, g.height);
        } catch (e) {}
        return tabBox.screenGeometry;
    }

    // ---- sizes ----------------------------------------------------------------
    // The largest thumbnail height, and the one in use: when there are too
    // many windows to fit, the layout shrinks the cards (as Windows does)
    // before it resorts to scrolling.
    readonly property int baseThumbHeight: Math.round(Math.min(170, Math.max(110, tabBox.home.height * 0.15)))
    readonly property int minThumbHeight: 72
    property int thumbHeight: tabBox.baseThumbHeight
    readonly property int headerHeight: 32
    readonly property int cardPad: 6          // around the thumbnail
    readonly property int gap: 12             // between cards
    readonly property int pad: 15             // inside the panel
    readonly property int ring: 5             // room for the selection ring
    readonly property int radius: 8
    readonly property real minCard: 150
    readonly property real maxCard: 380

    // ---- colours (from the active colour scheme) --------------------------------
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color cardBg: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color cardHover: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.85)
    readonly property color hairline: Qt.rgba(tabBox.ink.r, tabBox.ink.g, tabBox.ink.b, dark ? 0.12 : 0.10)

    // A fresh popup each time Alt+Tab opens (as KWin's own switchers do), so it
    // is always sized to what it holds.
    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.home.x + (tabBox.home.width - content.width) / 2
            y: tabBox.home.y + (tabBox.home.height - content.height) / 2

            mainItem: Item {
                id: content
                // The popup follows these as the cards lay out and rows are added.
                // Set as explicit sizes *and* layout hints: a Plasma popup sizes
                // itself once from its content, then only follows bound sizes.
                // What the cards need right now...
                readonly property real fitW: Math.max(240, wall.contentW) + 2 * tabBox.pad
                readonly property real fitH: Math.max(120, flick.height) + 2 * tabBox.pad
                // ...but never smaller than it has been while Alt is held. Closing a
                // window with X would otherwise shrink the panel, and the next click
                // could land outside it, which KWin treats as "cancel" and closes
                // the switcher. (A fresh popup is made each time Alt+Tab opens.)
                property real keptW: 0
                property real keptH: 0
                onFitWChanged: keptW = Math.max(keptW, fitW)
                onFitHChanged: keptH = Math.max(keptH, fitH)
                readonly property real wantW: Math.max(keptW, fitW)
                readonly property real wantH: Math.max(keptH, fitH)
                width: content.wantW
                height: content.wantH
                implicitWidth: content.wantW
                implicitHeight: content.wantH
                Layout.minimumWidth: content.wantW
                Layout.preferredWidth: content.wantW
                Layout.maximumWidth: content.wantW
                Layout.minimumHeight: content.wantH
                Layout.preferredHeight: content.wantH
                Layout.maximumHeight: content.wantH
                focus: true

                // ---- moving -------------------------------------------------------------------
                function select(i) {
                    if (i >= 0 && i < cards.count)
                        tabBox.currentIndex = i;
                }
                function step(delta) {
                    const n = cards.count;
                    if (n > 0)
                        content.select(((tabBox.currentIndex + delta) % n + n) % n);
                }
                // Up/Down: the card in the next row whose centre is nearest this one's.
                function vertical(dir) {
                    const g = wall.geo, cur = g[tabBox.currentIndex];
                    if (!cur) return;
                    const centre = cur.x + cur.w / 2;
                    let best = -1, bestDist = Infinity;
                    for (let i = 0; i < g.length; ++i) {
                        if (!g[i] || g[i].row !== cur.row + dir) continue;
                        const d = Math.abs(g[i].x + g[i].w / 2 - centre);
                        if (d < bestDist) { bestDist = d; best = i; }
                    }
                    content.select(best);
                }


                Flickable {
                    id: flick
                    x: (content.width - flick.width) / 2
                    y: (content.height - flick.height) / 2
                    width: wall.contentW
                    height: Math.min(wall.contentH, tabBox.home.height * 0.8)
                    contentWidth: wall.contentW
                    contentHeight: wall.contentH
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    function reveal(i) {
                        const g = wall.geo[i];
                        if (!g) return;
                        if (g.y - tabBox.ring < contentY) contentY = g.y - tabBox.ring;
                        else if (g.y + g.h + tabBox.ring > contentY + height) contentY = g.y + g.h + tabBox.ring - height;
                    }

                    Item {
                        id: wall
                        width: wall.contentW
                        height: wall.contentH

                        // Where every card goes: rows filled left to right up to
                        // about 80% of the screen, each row centred.
                        property var geo: []
                        property real contentW: 0
                        property real contentH: 0

                        // Card width for a thumbnail height: the window's shape, within limits.
                        function cardWidth(i, th) {
                            const it = cards.itemAt(i);
                            const aspect = it ? it.aspect : 16 / 10;
                            const k = th / tabBox.baseThumbHeight;
                            return Math.max(tabBox.minCard * k, Math.min(tabBox.maxCard * k, th * aspect)) + 2 * tabBox.cardPad;
                        }

                        // Rows for one thumbnail height: filled left to right up to
                        // about 80% of the screen's width, each row centred.
                        function arrange(th) {
                            const n = cards.count;
                            const maxW = tabBox.home.width * 0.8 - 2 * tabBox.pad;
                            const h = tabBox.headerHeight + th + tabBox.cardPad;
                            const rows = [];
                            let row = [], w = 0;
                            for (let i = 0; i < n; ++i) {
                                const cw = wall.cardWidth(i, th);
                                if (row.length > 0 && w + tabBox.gap + cw > maxW) {
                                    rows.push({ items: row, w: w });
                                    row = [];
                                    w = 0;
                                }
                                w += (row.length > 0 ? tabBox.gap : 0) + cw;
                                row.push({ i: i, w: cw });
                            }
                            if (row.length > 0) rows.push({ items: row, w: w });
                            let widest = 0;
                            for (const r of rows) widest = Math.max(widest, r.w);
                            const g = [];
                            rows.forEach((r, ri) => {
                                let x = (widest - r.w) / 2;
                                for (const c of r.items) {
                                    g[c.i] = { x: x + tabBox.ring, y: ri * (h + tabBox.gap) + tabBox.ring, w: c.w, h: h, row: ri };
                                    x += c.w + tabBox.gap;
                                }
                            });
                            return {
                                geo: g,
                                w: widest + 2 * tabBox.ring,
                                h: rows.length > 0 ? rows.length * (h + tabBox.gap) - tabBox.gap + 2 * tabBox.ring : 0
                            };
                        }

                        // Biggest cards that fit in 80% of the screen's height;
                        // below the minimum size it scrolls instead.
                        function layout() {
                            const maxH = tabBox.home.height * 0.8 - 2 * tabBox.pad;
                            let th = tabBox.baseThumbHeight;
                            let a = wall.arrange(th);
                            while (a.h > maxH && th > tabBox.minThumbHeight) {
                                th = Math.max(tabBox.minThumbHeight, th - 8);
                                a = wall.arrange(th);
                            }
                            tabBox.thumbHeight = th;
                            wall.geo = a.geo;
                            wall.contentW = a.w;
                            wall.contentH = a.h;
                            flick.reveal(tabBox.currentIndex);
                        }

                        Repeater {
                            id: cards
                            model: tabBox.model
                            onCountChanged: Qt.callLater(wall.layout)

                            delegate: Item {
                                id: card
                                required property int index
                                required property string caption
                                required property var icon
                                required property bool minimized
                                required property var windowId

                                readonly property bool selected: card.index === tabBox.currentIndex
                                readonly property bool hovered: cardHover.hovered
                                readonly property real aspect: thumb.implicitHeight > 0
                                    ? thumb.implicitWidth / thumb.implicitHeight : 16 / 10
                                onAspectChanged: Qt.callLater(wall.layout)

                                readonly property var g: wall.geo[card.index]
                                x: card.g ? card.g.x : 0
                                y: card.g ? card.g.y : 0
                                width: card.g ? card.g.w : tabBox.minCard
                                height: card.g ? card.g.h : tabBox.headerHeight + tabBox.thumbHeight + tabBox.cardPad

                                HoverHandler { id: cardHover }
                                // Click a card to switch to it. A plain click area *under* everything else
                                // (not a TapHandler, which would also see clicks on the X and close the
                                // switcher along with the window).
                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    onClicked: tabBox.model.activate(card.index)
                                }

                                // selection ring, just outside the card
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    radius: tabBox.radius + 4
                                    color: "transparent"
                                    border.width: 3
                                    border.color: tabBox.accent
                                    visible: card.selected
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: tabBox.radius
                                    color: card.hovered ? tabBox.cardHover : tabBox.cardBg
                                    border.width: 1
                                    border.color: tabBox.hairline
                                }

                                // header: icon and title, and the X on hover
                                Item {
                                    id: header
                                    x: 10
                                    width: parent.width - 16
                                    height: tabBox.headerHeight

                                    Kirigami.Icon {
                                        id: appIcon
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        source: card.icon
                                    }
                                    PlasmaComponents3.Label {
                                        anchors.left: appIcon.right
                                        anchors.leftMargin: 8
                                        anchors.right: closeButton.visible ? closeButton.left : parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: card.caption
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: tabBox.ink
                                    }
                                    Rectangle {
                                        id: closeButton
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 24
                                        height: 24
                                        radius: 4
                                        visible: card.hovered
                                        color: closeArea.containsMouse ? "#c42b1c" : "transparent"
                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: 12
                                            height: 12
                                            source: "window-close-symbolic"
                                            color: closeArea.containsMouse ? "#ffffff" : tabBox.ink
                                            isMask: true
                                        }
                                        MouseArea {
                                            id: closeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: tabBox.model.close(card.index)
                                        }
                                    }
                                }

                                // the window itself, fitted into the card keeping its shape
                                Item {
                                    id: frame
                                    x: tabBox.cardPad
                                    y: tabBox.headerHeight
                                    width: parent.width - 2 * tabBox.cardPad
                                    height: parent.height - tabBox.headerHeight - tabBox.cardPad

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: 48
                                        height: 48
                                        source: card.icon
                                        opacity: 0.5
                                    }
                                    KWin.WindowThumbnail {
                                        id: thumb
                                        wId: card.windowId
                                        anchors.centerIn: parent
                                        width: Math.min(frame.width, frame.height * card.aspect)
                                        height: Math.min(frame.height, frame.width / card.aspect)
                                    }
                                }
                            }
                        }
                    }
                }

                Connections {
                    target: tabBox
                    function onCurrentIndexChanged(): void { flick.reveal(tabBox.currentIndex); }
                    function onHomeChanged(): void { Qt.callLater(wall.layout); }
                    // Lay out before the popup is shown, so it opens at its real size.
                    function onModelChanged(): void { wall.layout(); }
                }

                Component.onCompleted: wall.layout()

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: cards.count === 0
                    text: "No open windows"
                    opacity: 0.7
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) { content.step(-1); event.accepted = true; }
                    else if (event.key === Qt.Key_Right) { content.step(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { content.vertical(-1); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { content.vertical(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Delete) {
                        if (cards.count > 0) tabBox.model.close(tabBox.currentIndex);
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
