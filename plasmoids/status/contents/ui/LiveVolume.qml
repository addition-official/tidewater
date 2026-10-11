// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The volume of the current output, live from Plasma's own volume module
// (plasma-pa), the same one Plasma's volume icon uses. Every change arrives at
// once, with no programs to start and no polling.
//
// main.qml loads this file with a Loader, so a Plasma without the module only
// loses the volume controls, not the whole widget.
import QtQuick
import org.kde.plasma.private.volume

Item {
    readonly property var sink: PreferredDevice.sink
    // "auto_null" is PulseAudio's stand-in when there is no real output
    readonly property bool ok: !!sink && sink.name !== "auto_null"
    readonly property int percent: ok ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : -1
    readonly property bool muted: ok ? sink.muted : false

    function setPercent(v) {
        if (!ok) return;
        sink.volume = Math.round(PulseAudio.NormalVolume * v / 100);
        if (sink.muted) sink.muted = false;
    }
    function toggleMute() {
        if (ok) sink.muted = !sink.muted;
    }

    // If the sound server is slow to come back (e.g. after sleep), the module
    // stops trying to reconnect after a few attempts and stays disconnected.
    // Plasma's volume icon shows a "Connect" button then; this presses it.
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: if (Context.state !== Context.State.Ready && !Context.autoConnecting)
            Context.reconnectDaemon()
    }
}
