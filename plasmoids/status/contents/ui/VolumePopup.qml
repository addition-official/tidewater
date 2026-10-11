// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The Windows 11 style volume popup: a small card at the bottom of the main
// monitor, just above the panel. It shows whenever the volume or mute changes
// (volume keys, a knob, headset buttons), except for changes made with
// Tidewater's own slider and scrolling. It takes no clicks and goes away on
// its own.
//
// The level comes live from Plasma's volume module (LiveVolume.qml), so the
// card always shows the real volume, as fast as it changes, and keeps working
// after sleep. Plasma's own popup is switched off while this one is on (see
// main.qml and helper.sh plasma-osd), so only one shows.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import "common"

Item {
    id: popup
    required property var pal
    // the main monitor's geometry, and the part of it the panels leave free
    // (relative to the monitor), both from the panel this widget sits in
    property rect screenGeometry
    property rect freeArea
    property bool showNumber: false
    property bool active: true
    property var live: null              // LiveVolume.qml, or null
    // Tidewater's own slider and scrolling set this, so their changes don't
    // show the card (you are already looking at the level)
    property double quietUntil: 0

    readonly property int vol: live ? live.percent : -1
    readonly property bool muted: live ? live.muted : false
    readonly property var sink: live ? live.sink : null

    // A different output (headphones plugged in) or the sound server just
    // (re)connecting, e.g. at login or after sleep: that isn't you changing
    // the volume, so the next moment doesn't count.
    property double switched: 0
    onSinkChanged: switched = Date.now()
    onLiveChanged: switched = Date.now()

    function changed() {
        const now = Date.now();
        if (!active || vol < 0 || now < quietUntil || now - switched < 500)
            return;
        if (!card.visible) {
            place();
            card.visible = true;
        }
        hideTimer.restart();
    }
    onVolChanged: changed()
    onMutedChanged: changed()

    function place() {
        const g = screenGeometry;
        const free = freeArea;
        // bottom of the free area (above the panel); the whole screen if unknown
        const bottom = free.height > 0 ? g.y + free.y + free.height : g.y + g.height - 56;
        card.x = Math.round(g.x + (g.width - card.width) / 2);
        card.y = Math.round(bottom - card.height - 12);
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: card.visible = false
    }
    onActiveChanged: if (!active) {
        hideTimer.stop();
        card.visible = false;
    }

    function glyphFor(v, m) {
        if (m || v <= 0)
            return "volume_off";
        if (v <= 25)
            return "volume_mute";
        if (v <= 75)
            return "volume_down";
        return "volume_up";
    }

    // Plasma's popup frame (the same kind the taskbar previews use), so it has
    // the theme's rounded corners, shadow and blur. A tooltip-type window
    // stays above full-screen video, like the Windows one.
    PlasmaCore.Dialog {
        id: card
        type: PlasmaCore.Dialog.Tooltip
        location: PlasmaCore.Types.Floating
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        visible: false
        // keep it centered when it changes size (the number turned on or off)
        onWidthChanged: if (visible)
            popup.place()

        mainItem: Item {
            width: content.width
            height: content.height

            Row {
                id: content
                height: 44
                leftPadding: 14
                rightPadding: popup.showNumber ? 14 : 18
                spacing: 14

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: popup.glyphFor(popup.vol, popup.muted)
                    fallback: popup.muted || popup.vol <= 0 ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                    size: 20
                    color: popup.pal.fg
                    fontAvailable: popup.pal.hasIconFont
                }
                // the level, like the quick settings slider (no handle: it
                // can't be dragged); grayed out while muted
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    height: 4
                    radius: 2
                    color: popup.pal.alpha(popup.pal.fg, 0.2)
                    // drawn at the new level at once: an animation here would
                    // restart on every step of a fast knob and always trail behind
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, popup.vol)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: popup.muted ? popup.pal.mut : popup.pal.acc
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: popup.showNumber
                    width: 28        // room for "100", so the card doesn't jump
                    horizontalAlignment: Text.AlignRight
                    text: Math.max(0, popup.vol)
                    color: popup.pal.fg
                    font.family: popup.pal.font
                    font.pixelSize: 14
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
