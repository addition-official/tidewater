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
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings, shared by every Tidewater widget.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Right-click > "Tidewater settings...": opens the start button's settings
    // page, where all of Tidewater is set up (hidden without a start button).
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Tidewater settings..."
            icon.name: "configure"
            visible: Settings.canOpen
            onTriggered: Settings.openSettings()
        }
    ]

    Palette { id: design }

    // ---- volume popup (Windows style) --------------------------------------------
    // Shown by one quick settings widget: the one on the main monitor (see
    // Settings.volumeHost).
    readonly property bool onMainScreen: Plasmoid.containment !== null && Plasmoid.containment.screen === 0
    readonly property bool volumeHost: Settings.volumeHost === root
    Component.onDestruction: Settings.removeStatus(root)
    // Plasma's own popup is off while ours is on, and comes back (as you had it)
    // when ours is switched off. A moment after start: at login the saved
    // settings arrive just after the widgets.
    onVolumeHostChanged: if (volumeHost) plasmaOsd.restart()
    Connections {
        target: Settings
        function onVolumePopupChanged() { if (root.volumeHost) plasmaOsd.restart(); }
    }
    Timer {
        id: plasmaOsd
        interval: 2500
        onTriggered: if (root.volumeHost) root.sh("plasma-osd " + (Settings.volumePopup ? "off" : "on"))
    }
    VolumePopup {
        id: volumePopup
        pal: design
        active: root.volumeHost && Settings.volumePopup
        showNumber: Settings.volumeNumber
        live: root.live
        screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
        freeArea: Plasmoid.containment ? Plasmoid.containment.availableScreenRect : Qt.rect(0, 0, 0, 0)
    }

    // Everything the helper reports. See helper.sh status.
    property var st: ({})
    readonly property bool ready: st.user !== undefined

    readonly property string helper: {
        const u = Qt.resolvedUrl("../code/helper.sh").toString();
        return u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
    }
    function sh(args, repeat) { exec.run("bash " + exec.q(helper) + " " + args, repeat); }
    // With a time limit: if something it asks hangs (it can, right after sleep),
    // the next check still runs instead of everything staying frozen.
    function refresh() { exec.run("timeout 5 bash " + exec.q(helper) + " status"); }
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

    // ---- volume ---------------------------------------------------------------
    // One source: Plasma's own volume module (LiveVolume.qml), the same one
    // Plasma's volume icon uses. Every change shows at once, even a knob spun
    // fast, and it reconnects by itself after sleep.
    Loader { id: liveLoader; source: "LiveVolume.qml" }
    readonly property var live: liveLoader.item
    readonly property int volNow: live ? live.percent : -1
    readonly property bool mutedNow: live ? live.muted : false
    function setVolume(v) {
        volumePopup.quietUntil = Date.now() + 1000;     // no popup for our own slider
        if (live) live.setPercent(Math.max(0, Math.min(100, Math.round(v))));
    }
    function toggleMute() {
        volumePopup.quietUntil = Date.now() + 1000;
        if (live) live.toggleMute();
    }
    Component.onCompleted: Settings.addStatus(root)

    Exec {
        id: exec
        onFinished: (cmd, out, code) => {
            if (cmd.endsWith(" status")) {
                let next;
                try { next = JSON.parse(out); }
                catch (e) {
                    // not the output itself: it holds user and network names
                    console.warn("tidewater: could not read status (" + String(out).length + " characters): " + e.message);
                    return;
                }
                root.absorb(next);
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
    readonly property string volGlyph: volumeGlyph(Math.max(0, volNow) / 100, mutedNow)
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
                             "Volume " + (mutedNow ? "muted" : volNow + "%")].join(" · ") : ""

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
                    svg: root.st.ethOn ? "ethernet" : ""
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
                // Touchpads send many small steps: add them up and change the
                // volume by 5% for each full notch (120), starting over when
                // the direction changes.
                property real wheelAcc: 0
                onWheel: wheel => {
                    const d = wheel.angleDelta.y;
                    if (root.volNow < 0 || d === 0) return;
                    if ((wheelAcc > 0) !== (d > 0)) wheelAcc = 0;
                    wheelAcc += d;
                    const n = Math.trunc(wheelAcc / 120);   // whole notches only
                    if (n === 0) return;
                    wheelAcc -= n * 120;
                    // above 100% (set elsewhere), scrolling up must not pull it down to 100
                    if (n > 0 && root.volNow >= 100) return;
                    root.setVolume(root.volNow + 5 * n);
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
            if (root.volNow >= 0) vol.set(root.volNow);
            if (root.st.bri >= 0) bri.set(root.st.bri);
        }
        // the card is built on first open: show the levels we already know
        Component.onCompleted: syncSliders()
        Connections {
            target: root
            function onStChanged() { cardRoot.syncSliders(); }
            function onVolNowChanged() { if (root.volNow >= 0) vol.set(root.volNow); }
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
                    glyph: "lan"
                    svg: "ethernet"   // Tidewater's own drawing (see common/Glyph.qml)
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
                    visible: root.volNow >= 0
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
