// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// When the notifications were last read, shared by every Tidewater bell in
// this Plasma session: reading them on one monitor clears the badge on all.
pragma Singleton
import QtQuick

QtObject {
    property string lastRead: ""      // ISO time, or empty for never
    // Keep the later of the two, so an older saved time never undoes a newer one.
    function offer(iso) { if (iso && iso > lastRead) lastRead = iso; }
}
