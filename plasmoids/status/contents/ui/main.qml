// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Network, Bluetooth and volume icons for the panel, and the quick settings
// card they open.
// All system access goes through ../code/helper.sh.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Palette { id: design }

    // Everything the helper reports. See helper.sh status.
    property var st: ({})
    readonly property bool ready: st.user !== undefined

    readonly property string helper: {
        const u = Qt.resolvedUrl("../code/helper.sh").toString();
        return u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
    }
    function sh(args, repeat) { exec.run("bash " + exec.q(helper) + " " + args, repeat); }
    function refresh() { sh("status"); }
    function patch(obj) { root.st = Object.assign({}, root.st, obj); }

    // When you tap something, it changes on screen at once and *stays* changed
    // for a moment: a status read that started before your tap would otherwise
    // come back with the old value and flip it back ("flips for a sec").
    property var holds: ({})                  // key -> time our value wins until
    function hold(obj) {
        const until = Date.now() + 2500;
        const h = Object.assign({}, root.holds);
        for (const k in obj) h[k] = until;
        root.holds = h;
        patch(obj);
    }
    function held(k) { return (root.holds[k] || 0) > Date.now(); }
    // Take values from the system, except ones we are still holding.
    function absorb(next) {
        const merged = Object.assign({}, next);
        for (const k in root.holds)
            if (held(k) && k in root.st) merged[k] = root.st[k];
        root.st = merged;
    }
    function openPage(module) {
        sh("open systemsettings " + module);
        root.expanded = false;
    }

    // ---- volume: straight to PipeWire, no helper, no waiting -------------------
    readonly property string volGet: "wpctl get-volume @DEFAULT_AUDIO_SINK@"
    property int volSent: -1
    property int volWanted: -1

    // Set the volume now; while dragging, at most every 50 ms.
    function setVolume(v) {
        v = Math.max(0, Math.min(100, Math.round(v)));
        hold({ vol: v, muted: false });
        volWanted = v;
        if (!volThrottle.running) { sendVolume(); volThrottle.start(); }
    }
    function sendVolume() {
        if (volWanted < 0 || volWanted === volSent) return;
        volSent = volWanted;
        exec.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + volWanted + "%");
        exec.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0");
    }
    function toggleMute() {
        hold({ muted: !root.st.muted });
        exec.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", true);   // true: a quick 2nd click counts
    }
    Timer { id: volThrottle; interval: 50; onTriggered: root.sendVolume() }

    // Listen for sound changes (volume keys, other apps) and update at once.
    // If that isn't possible (no pactl), fall back to checking twice a second.
    readonly property string watchCmd: "bash " + exec.q(helper) + " watch-audio"
    property bool canListen: true
    property double watchStarted: 0
    property int quickExits: 0
    function listen() { watchStarted = Date.now(); exec.run(watchCmd); }
    Timer { id: relisten; interval: 100; onTriggered: root.listen() }
    Timer { id: retryListen; interval: 300000; onTriggered: { root.quickExits = 0; root.canListen = true; root.listen(); } }
    Component.onCompleted: { listen(); exec.run(volGet); }
    Timer {
        interval: root.canListen ? 10000 : 500
        running: true
        repeat: true
        onTriggered: exec.run(root.volGet)
    }

    Exec {
        id: exec
        onFinished: (cmd, out, code) => {
            if (cmd.endsWith(" status")) {
                let next;
                try { next = JSON.parse(out); }
                catch (e) { console.warn("tidewater: could not read status:", out); return; }
                root.absorb(next);
            } else if (cmd === root.volGet) {
                const m = /Volume:\s*([0-9.]+)/.exec(out);
                if (m) {
                    const next = Object.assign({}, root.st);
                    next.vol = Math.round(parseFloat(m[1]) * 100);
                    next.muted = out.indexOf("MUTED") >= 0;
                    root.absorb(next);
                }
            } else if (cmd === root.watchCmd) {
                if (code === 3) { root.canListen = false; return; }     // no pactl: poll
                // Read the new state and listen again. Only a quick exit WITHOUT a
                // real change ("hit") counts as the listener failing; after 5 in a
                // row, poll for a while and try listening again later.
                const hit = out.indexOf("hit") >= 0;
                root.quickExits = !hit && Date.now() - root.watchStarted < 1000 ? root.quickExits + 1 : 0;
                if (root.quickExits >= 5) { root.canListen = false; retryListen.restart(); return; }
                exec.run(root.volGet);
                relisten.restart();
            } else if (cmd.startsWith("wpctl ")) {
                // our own volume changes: the listener reports them back
            } else {
                settle.restart();
            }
        }
    }
    Timer { id: settle; interval: 600; onTriggered: root.refresh() }
    Timer {
        interval: root.expanded ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onExpandedChanged: if (expanded) refresh()

    // ---- which icon for which state ---------------------------------------------
    function wifiGlyph(strength) {
        if (!(strength > 0.05)) return "signal_wifi_0_bar";
        if (strength < 0.3) return "network_wifi_1_bar";
        if (strength < 0.55) return "network_wifi_2_bar";
        if (strength < 0.8) return "network_wifi_3_bar";
        return "signal_wifi_4_bar";
    }
    function volumeGlyph(v, muted) {
        if (muted || !(v > 0)) return "volume_off";
        if (v <= 0.25) return "volume_mute";
        if (v <= 0.75) return "volume_down";
        return "volume_up";
    }
    function brightnessGlyph(f) {
        if (f < 0.34) return "brightness_low";
        return f < 0.67 ? "brightness_medium" : "brightness_high";
    }
    // How many tiles show: Wi-Fi and Bluetooth only with hardware.
    readonly property int tileCount: 4 + (st.wifiHw ? 1 : 0) + (st.btHw ? 1 : 0)
    readonly property string netGlyph: st.ethOn ? "lan" : st.ssid ? wifiGlyph((st.signal || 0) / 100) : "signal_wifi_off"
    readonly property string btGlyph: !st.btOn ? "bluetooth_disabled" : st.btConnected > 0 ? "bluetooth_connected" : "bluetooth"
    readonly property string volGlyph: volumeGlyph((st.vol || 0) / 100, st.muted)
    readonly property string nightState: !st.nlOn ? "off" : st.nlInhibited ? "suspended" : st.nlRunning ? "warm" : "day"

    function uptimeText(sec) {
        if (!sec) return "";
        const d = Math.floor(sec / 86400);
        const h = Math.floor(sec % 86400 / 3600);
        const m = Math.floor(sec % 3600 / 60);
        const mm = (m < 10 ? "0" : "") + m;
        return d > 0 ? "up " + d + " d " + h + " h" : "up " + h + " h " + mm + " min";
    }

    toolTipMainText: "Quick settings"
    toolTipSubText: ready ? [st.ethOn ? "Ethernet" : (st.ssid || "No network"),
                             "Volume " + (st.muted ? "muted" : st.vol + "%")].join(" · ") : ""

    // ---- In the panel ---------------------------------------------------------
    compactRepresentation: Item {
        Layout.minimumWidth: group.width
        Layout.preferredWidth: group.width
        Layout.maximumWidth: group.width
        Layout.fillHeight: true

        // One button for all three icons: one hover pill, one click target
        // (scroll over it for volume, middle-click to mute).
        Rectangle {
            id: group
            anchors.centerIn: parent
            readonly property real h: Math.max(22, Math.round(40 * design.unit))
            width: icons.implicitWidth + 2 * Math.round(10 * Math.max(0.75, design.unit))
            height: h
            radius: Math.round(h * 0.32)
            color: area.containsMouse || root.expanded ? design.s2 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: icons
                anchors.centerIn: parent
                spacing: Math.round(10 * Math.max(0.75, design.unit))
                readonly property real glyph: Math.max(16, Math.round(20 * design.unit))
                Glyph {
                    name: root.netGlyph; fallback: "network-wireless-symbolic"
                    size: icons.glyph; color: design.fg; fontAvailable: design.hasIconFont
                }
                Glyph {
                    visible: root.st.btHw !== false
                    name: root.btGlyph; fallback: "network-bluetooth-symbolic"
                    size: icons.glyph; color: design.fg; fontAvailable: design.hasIconFont
                }
                Glyph {
                    name: root.volGlyph; fallback: "audio-volume-high-symbolic"
                    size: icons.glyph; color: design.fg; fontAvailable: design.hasIconFont
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) root.toggleMute();
                    else root.expanded = !root.expanded;
                }
                onWheel: wheel => {
                    if (!root.ready || root.st.vol < 0) return;
                    // above 100% (set elsewhere), scrolling up must not pull it down to 100
                    if (wheel.angleDelta.y > 0 && root.st.vol >= 100) return;
                    if (wheel.angleDelta.y === 0) return;
                    root.setVolume(root.st.vol + (wheel.angleDelta.y > 0 ? 5 : -5));
                }
            }
        }
    }

    // ---- The card -------------------------------------------------------------
    fullRepresentation: Item {
        id: cardRoot
        Layout.preferredWidth: 384
        Layout.minimumWidth: 384
        Layout.maximumWidth: 384
        Layout.preferredHeight: card.implicitHeight + 40
        Layout.minimumHeight: Layout.preferredHeight
        // Exactly as tall as the content: without a maximum, Plasma can make
        // the popup taller (or keep an old, larger size) and leave empty space.
        Layout.maximumHeight: Layout.preferredHeight

        function syncSliders() {
            if (root.st.vol >= 0) vol.set(root.st.vol);
            if (root.st.bri >= 0) bri.set(root.st.bri);
        }
        // the card is built on first open: show the levels we already know
        Component.onCompleted: syncSliders()
        Connections {
            target: root
            function onStChanged() { cardRoot.syncSliders(); }
        }

        ColumnLayout {
            id: card
            // Pinned to the top, not filling: if the popup ends up taller than
            // the content, the extra goes below instead of opening gaps between
            // the sections (e.g. under the tiles).
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            // Header: avatar, name, host and uptime, settings and power
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 12

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: design.accC
                    clip: true
                    Text {
                        anchors.centerIn: parent
                        visible: !face.visible
                        text: (root.st.fullName || root.st.user || "?").charAt(0).toUpperCase()
                        font.family: design.font
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: design.accCFg
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: root.st.avatar ? "file://" + root.st.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(80, 80)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.st.user || ""
                        font.family: design.font
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        color: design.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: [root.st.host, root.uptimeText(root.st.uptime)].filter(s => s).join(" · ")
                        textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                        font.family: design.font
                        font.pixelSize: 12
                        color: design.mut
                    }
                }

                IconButton {
                    pal: design; glyph: "tune"; fallback: "configure"
                    onClicked: { root.sh("open systemsettings"); root.expanded = false; }
                }
                IconButton {
                    pal: design; glyph: "power_settings_new"; fallback: "system-shutdown"
                    onClicked: { root.expanded = false; root.sh("power"); }
                }
            }

            // Tiles: two columns, the odd one out takes the whole row
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                uniformCellWidths: true

                Tile {
                    pal: design
                    title: "Wi-Fi"
                    visible: !!root.st.wifiHw           // no Wi-Fi hardware: no tile
                    glyph: !root.st.wifiOn ? "wifi_off" : root.wifiGlyph((root.st.signal || 0) / 100)
                    fallback: "network-wireless-symbolic"
                    hasPage: true
                    available: !!root.st.wifiHw
                    on: !!root.st.wifiOn && available
                    subtitle: !root.st.wifiHw ? "No adapter"
                        : root.st.wifiBlocked ? "Off (hardware switch)"
                        : !root.st.wifiOn ? "Off" : (root.st.ssid || "Not connected")
                    onToggled: { root.hold({ wifiOn: !root.st.wifiOn }); root.sh("wifi " + (root.st.wifiOn ? "on" : "off")); }
                    onPageRequested: root.openPage("kcm_networkmanagement")
                }
                Tile {
                    pal: design
                    title: "Ethernet"
                    glyph: root.st.ethOn ? "settings_ethernet" : "lan"
                    fallback: "network-wired-symbolic"
                    hasPage: true
                    available: !!root.st.ethHw
                    on: !!root.st.ethOn
                    subtitle: !root.st.ethHw ? "No adapter" : !root.st.ethOn ? "Disconnected"
                        : ["Ethernet", root.st.ethSpeed].filter(s => s).join(" · ")
                    onToggled: root.openPage("kcm_networkmanagement")
                    onPageRequested: root.openPage("kcm_networkmanagement")
                }
                Tile {
                    pal: design
                    title: "Bluetooth"
                    visible: !!root.st.btHw
                    glyph: root.btGlyph
                    fallback: "network-bluetooth-symbolic"
                    hasPage: true
                    available: !!root.st.btHw
                    on: !!root.st.btOn
                    // The kernel sees an adapter the Bluetooth service can't use.
                    readonly property bool stuck: !!root.st.btHw && root.st.btOk === false
                    subtitle: !root.st.btHw ? "No adapter" : stuck ? "Adapter not responding" : !root.st.btOn ? "Off"
                        : root.st.btConnected > 0 ? root.st.btConnected + " connected" : "On"
                    onToggled: {
                        if (stuck) { root.openPage("kcm_bluetooth"); return; }
                        root.hold({ btOn: !root.st.btOn });
                        root.sh("bluetooth " + (root.st.btOn ? "on" : "off"));
                    }
                    onPageRequested: root.openPage("kcm_bluetooth")
                }
                Tile {
                    pal: design
                    title: "Microphone"
                    glyph: root.st.micOn ? "mic" : "mic_off"
                    fallback: "audio-input-microphone-symbolic"
                    hasPage: true
                    available: !!root.st.micHw
                    on: !!root.st.micOn
                    subtitle: !root.st.micHw ? "No microphone" : !root.st.micOn ? "Muted" : (root.st.micName || "On")
                    onToggled: { root.hold({ micOn: !root.st.micOn }); root.sh("mic", true); }
                    onPageRequested: root.openPage("kcm_pulseaudio")
                }
                Tile {
                    pal: design
                    title: "Do not disturb"
                    glyph: root.st.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    fallback: "notifications-disabled-symbolic"
                    on: !!root.st.dnd
                    subtitle: root.st.dnd ? "On" : "Off"
                    onToggled: { root.hold({ dnd: !root.st.dnd }); root.sh("dnd " + (root.st.dnd ? "on" : "off")); }
                }
                Tile {
                    pal: design
                    title: "Night Light"
                    // alone on its row when an odd number of tiles is showing
                    Layout.columnSpan: root.tileCount % 2 === 1 ? 2 : 1
                    glyph: root.nightState === "suspended" ? "bedtime_off" : root.nightState === "day" ? "light_mode" : "nightlight"
                    fallback: "redshift-status-on"
                    hasPage: true
                    available: !!root.st.nlHw
                    on: root.nightState === "warm" || root.nightState === "day"
                    subtitle: !root.st.nlHw ? "Unavailable" : root.nightState === "off" ? "Off"
                        : root.nightState === "suspended" ? "Suspended" : root.nightState === "warm" ? "On" : "Daytime"
                    onToggled: {
                        if (!root.st.nlOn) { root.openPage("kcm_nightlight"); return; }
                        root.hold({ nlInhibited: !root.st.nlInhibited });
                        root.sh("nightlight");
                    }
                    onPageRequested: root.openPage("kcm_nightlight")
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: design.out }

            // Levels
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.st.vol !== undefined && root.st.vol >= 0
                    spacing: 10
                    IconButton {
                        pal: design; size: 30; glyph: root.volGlyph; fallback: "audio-volume-high-symbolic"
                        onClicked: root.toggleMute()
                    }
                    LevelSlider {
                        id: vol
                        pal: design
                        Layout.fillWidth: true
                        onMoved: v => root.setVolume(v)
                    }
                    IconButton {
                        pal: design; size: 30; glyph: "chevron_right"; fallback: "go-next-symbolic"
                        onClicked: root.openPage("kcm_pulseaudio")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.st.bri !== undefined && root.st.bri >= 0
                    spacing: 10
                    Item {
                        implicitWidth: 30; implicitHeight: 30
                        Glyph {
                            anchors.centerIn: parent
                            name: root.brightnessGlyph((root.st.bri || 0) / 100)
                            fallback: "brightness-high-symbolic"
                            size: 17
                            color: design.fg
                            fontAvailable: design.hasIconFont
                        }
                    }
                    LevelSlider {
                        id: bri
                        pal: design
                        from: 1
                        Layout.fillWidth: true
                        property int pending: 0
                        onMoved: v => { pending = Math.round(v); briDebounce.restart(); }
                        Timer {
                            id: briDebounce; interval: 60
                            onTriggered: { const v = bri.pending; root.hold({ bri: v }); root.sh("brightness " + v); }
                        }
                    }
                    IconButton {
                        pal: design; size: 30; glyph: "chevron_right"; fallback: "go-next-symbolic"
                        onClicked: root.openPage("kcm_kscreen")
                    }
                }
            }
        }
    }
}
