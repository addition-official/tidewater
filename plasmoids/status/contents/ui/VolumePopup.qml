// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The Windows 11 style volume popup: a small card at the bottom of the main
// monitor, just above the panel, shown when a volume key is pressed (never for
// sliders, scrolling or apps). A speaker icon, a level bar and, if you like,
// the number. It takes no clicks and goes away on its own.
//
// Plasma's own popup is switched off while this one is on (see main.qml and
// helper.sh plasma-osd), so only one shows.
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

    // The live volume (LiveVolume.qml, through the widget this sits in), or
    // null without Plasma's volume module. With it, the card simply shows the
    // real level as it changes, exactly as fast as Plasma's own popup.
    property var live: null
    readonly property int shownVol: live ? live.percent : vol
    readonly property bool shownMuted: live ? live.muted : muted

    // Without the live volume: the level last read from the system (by the
    // widget this sits in), used as the starting point when the card opens.
    property int knownVol: -1
    property bool knownMuted: false

    // ---- the level without the live volume ----------------------------------------
    // Worked out here for every key press, the same way Plasma's audio service
    // changes the volume (its step, its limit, a key at 0 % mutes and any
    // other level unmutes), so the card keeps up however fast the keys come,
    // e.g. a volume knob twisted quickly. Once the keys stop, the real level is
    // read once to make sure (anything else that changed it meanwhile).
    property int vol: -1
    property bool muted: false
    property int step: 5             // Plasma's volume step (System Settings > Sound)
    property int maxVol: 100         // 150 with "Raise maximum volume"
    property double lastPress: 0
    property int readSeq: 0
    property var readStarted: ({})   // read number -> when it started

    readonly property string volGet: "wpctl get-volume @DEFAULT_AUDIO_SINK@"
    readonly property string cfgGet: "sh -c 'kreadconfig6 --file plasmaparc --group General --key VolumeStep --default 5;"
        + " kreadconfig6 --file plasmaparc --group General --key RaiseMaximumVolume --default false'"

    function readLevel() {
        const n = ++readSeq;
        const r = Object.assign({}, readStarted);
        r[n] = Date.now();
        readStarted = r;
        exec.start(volGet + " #read" + n);
    }

    Exec {
        id: exec
        onFinished: (cmd, out, code) => {
            if (cmd === popup.cfgGet) {
                const lines = String(out).trim().split("\n");
                const st = parseInt(lines[0]);
                popup.step = st > 0 && st <= 100 ? st : 5;
                popup.maxVol = String(lines[1]).trim() === "true" ? 150 : 100;
                return;
            }
            const n = /#read(\d+)$/.exec(cmd);
            if (!n)
                return;
            const started = popup.readStarted[n[1]];
            const r = Object.assign({}, popup.readStarted);
            delete r[n[1]];
            popup.readStarted = r;
            // a key pressed after this read began: its answer is already old
            if (!(started > popup.lastPress))
                return;
            const m = /Volume:\s*([0-9.]+)/.exec(out);
            if (!m)
                return;
            popup.vol = Math.round(parseFloat(m[1]) * 100);
            popup.muted = out.indexOf("MUTED") >= 0;
        }
    }

    // One volume or mute key press (or a repeat of a held key).
    function keyPressed(key) {
        if (!active)
            return;
        if (live) {
            // Plasma changes the volume itself; the bar follows the real level
            show();
            return;
        }
        if (!card.visible) {
            // the widget's level, unless this card's own is fresher (it just
            // closed: the widget only catches up within a second or so)
            if (knownVol >= 0 && (vol < 0 || Date.now() - lastPress > 3000)) {
                vol = knownVol;
                muted = knownMuted;
            }
            exec.run(cfgGet);        // in case the step was changed
        }
        if (vol < 0) {
            // nothing known yet (just after login): show once it has been read
            lastPress = Date.now();
            settle.restart();
            return;
        }
        apply(key);
        lastPress = Date.now();
        show();
        settle.restart();
    }
    function apply(key) {
        if (key === "mute") {
            muted = !muted;
            return;
        }
        const delta = { increase_volume: step, decrease_volume: -step,
            increase_volume_small: 1, decrease_volume_small: -1 }[key] || 0;
        vol = Math.max(0, Math.min(maxVol, vol + delta));
        muted = vol === 0;
    }
    function show() {
        if (!card.visible) {
            place();
            card.visible = true;
        }
        hideTimer.restart();
    }
    function place() {
        const g = screenGeometry;
        const free = freeArea;
        // bottom of the free area (above the panel); the whole screen if unknown
        const bottom = free.height > 0 ? g.y + free.y + free.height : g.y + g.height - 56;
        card.x = Math.round(g.x + (g.width - card.width) / 2);
        card.y = Math.round(bottom - card.height - 12);
    }

    // The keys have stopped for a moment: read the real level (and show the
    // card if it was waiting for one).
    Timer {
        id: settle
        interval: 250
        onTriggered: popup.readLevel()
    }
    onVolChanged: if (!live && vol >= 0 && !card.visible && settle.running === false && Date.now() - lastPress < 1000)
        show()

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: card.visible = false
    }

    onActiveChanged: {
        if (active) {
            exec.run(cfgGet);        // Plasma's step and limit, before the first key
        } else {
            hideTimer.stop();
            card.visible = false;
        }
    }
    Component.onCompleted: if (active)
        exec.run(cfgGet)

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
                    name: popup.glyphFor(popup.shownVol, popup.shownMuted)
                    fallback: popup.shownMuted || popup.shownVol <= 0 ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
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
                        width: parent.width * Math.max(0, Math.min(100, popup.shownVol)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: popup.shownMuted ? popup.pal.mut : popup.pal.acc
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: popup.showNumber
                    width: 28        // room for "100", so the card doesn't jump
                    horizontalAlignment: Text.AlignRight
                    text: Math.max(0, popup.shownVol)
                    color: popup.pal.fg
                    font.family: popup.pal.font
                    font.pixelSize: 14
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
