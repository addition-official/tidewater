// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// When the notifications were last read, shared by every Tidewater widget that
// shows them (the clock, and the bell if it is on) in this Plasma session:
// reading them in one place, or on one monitor, clears the badge everywhere.
pragma Singleton
import QtQuick

QtObject {
    property string lastRead: ""      // ISO time, or empty for never
    // Keep the later of the two, so an older saved time never undoes a newer one.
    function offer(iso) { if (iso && iso > lastRead) lastRead = iso; }
}
