// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Tells when a volume key (or a headset's volume button) is pressed, and only
// then: sliders, scrolling and apps changing the volume don't count.
// Plasma's shortcut service announces every shortcut press on D-Bus; the
// volume ones belong to the "kmix" group (Plasma's audio keeps that old name).
// Loaded through a Loader, so a Plasma without this D-Bus module only loses
// the popup, not the whole widget.
import QtQuick
import org.kde.plasma.workspace.dbus as DBus

DBus.SignalWatcher {
    signal pressed(string key)

    busType: DBus.BusType.Session
    service: "org.kde.kglobalaccel"
    path: "/component/kmix"
    iface: "org.kde.kglobalaccel.Component"

    readonly property var keys: ["increase_volume", "decrease_volume",
        "increase_volume_small", "decrease_volume_small", "mute"]

    // The names must be "dbus" + the D-Bus signal's name. A held key repeats.
    function dbusglobalShortcutPressed(component, shortcut, timestamp) {
        if (keys.indexOf(String(shortcut)) >= 0)
            pressed(String(shortcut));
    }
    function dbusglobalShortcutRepeated(component, shortcut, timestamp) {
        dbusglobalShortcutPressed(component, shortcut, timestamp);
    }
    // nothing to do, but without it every key release logs a warning
    function dbusglobalShortcutReleased(component, shortcut, timestamp) {
    }
}
