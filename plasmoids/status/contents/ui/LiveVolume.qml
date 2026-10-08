// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The volume of the current output, live from PulseAudio/PipeWire, the same
// way Plasma's own volume popup gets it: no programs to start, no polling.
// A volume knob spun fast shows every step the moment it happens.
//
// Uses Plasma's own volume module (from plasma-pa, which Plasma's hidden
// volume icon needs anyway). main.qml loads this file with a Loader: if the
// module is missing, the load fails and main.qml falls back to wpctl.
import QtQuick
import org.kde.plasma.private.volume

Item {
    readonly property var sink: PreferredDevice.sink
    // "auto_null" is PulseAudio's stand-in when there is no real output
    readonly property bool ok: !!sink && sink.name !== "auto_null"
    readonly property int percent: ok ? Math.round(sink.volume / PulseAudio.NormalVolume * 100) : -1
    readonly property bool muted: ok ? sink.muted : false

    function setPercent(v) {
        if (!ok) return false;
        sink.volume = Math.round(PulseAudio.NormalVolume * v / 100);
        if (sink.muted) sink.muted = false;
        return true;
    }
    function toggleMute() {
        if (!ok) return false;
        sink.muted = !sink.muted;
        return true;
    }
}
