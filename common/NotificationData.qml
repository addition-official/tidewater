// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The notifications, for the clock's popup (and the bell, if it is on):
// Plasma's notification history, newest first, with Do not disturb, the
// unread count and the actions. Nothing is drawn here; NotificationPanel.qml
// shows it.
//
// Read state: `lastRead` comes in from outside (ReadMark, shared by every
// widget and monitor); markRead() returns the new time for the owner to
// share and save.
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: data
    visible: false

    property string lastRead: ""
    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: data.now = Date.now() }

    NotificationManager.Settings {
        id: settings
        live: true
    }
    readonly property bool quiet: {
        const until = settings.notificationsInhibitedUntil;
        return (until && until.getTime && until.getTime() > data.now) || settings.notificationsInhibitedByApplication;
    }
    function toggleDnd() {
        if (quiet) {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            settings.notificationsInhibitedUntil = d;
        }
        settings.save();
        data.now = Date.now();
    }

    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency
        onCountChanged: rebuild.restart()
        onDataChanged: rebuild.restart()
        Component.onCompleted: rebuild.restart()
    }
    onLastReadChanged: if (lastRead) history.lastRead = new Date(lastRead)
    Component.onCompleted: if (lastRead) history.lastRead = new Date(lastRead)

    // Notifications newer than the last time they were read. Counted here,
    // not with Plasma's own count: that one doesn't count anything while a
    // pop-up is still on screen, so the badge only went up once it was gone.
    readonly property int unseen: {
        const since = lastRead ? Date.parse(lastRead) : 0;
        let n = 0;
        for (const e of entries)
            if (e.when && e.when.getTime() > since)
                ++n;
        return n;
    }
    readonly property int count: entries.length
    // A time for "read up to now", for the owner to share and save.
    function markRead() {
        const iso = new Date().toISOString();
        history.lastRead = new Date(iso);
        return iso;
    }

    // Notification bodies may carry a little HTML: keep the text, line breaks
    // and the common entities (shown as plain text, never rendered).
    function plainBody(html) {
        return String(html || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'").replace(/&nbsp;/g, " ")
            .replace(/&amp;/g, "&");
    }

    // Every notification, newest first.
    property var entries: []
    Timer { id: rebuild; interval: 50; onTriggered: data.rebuildEntries() }
    function rebuildEntries() {
        const R = NotificationManager.Notifications;
        const out = [];
        for (let i = 0; i < history.count; ++i) {
            const idx = history.index(i, 0);
            out.push({
                id: history.data(idx, R.IdRole),
                app: history.data(idx, R.ApplicationNameRole) || "System",
                icon: history.data(idx, R.ApplicationIconNameRole) || "",
                summary: history.data(idx, Qt.DisplayRole) || "",
                body: data.plainBody(history.data(idx, R.BodyRole)),
                when: history.data(idx, R.CreatedRole),
                critical: history.data(idx, R.UrgencyRole) === NotificationManager.Notifications.CriticalUrgency,
                hasDefault: history.data(idx, R.HasDefaultActionRole) === true
            });
        }
        out.sort((x, y) => (y.when || 0) - (x.when || 0));
        entries = out;
    }

    // Rows move as notifications arrive, so act on a notification by its id.
    function rowOf(id) {
        for (let i = 0; i < history.count; ++i) {
            const idx = history.index(i, 0);
            if (history.data(idx, NotificationManager.Notifications.IdRole) === id) return idx;
        }
        return null;
    }
    function invoke(id) { const idx = rowOf(id); if (idx) history.invokeDefaultAction(idx); }
    function dismiss(id) { const idx = rowOf(id); if (idx) history.close(idx); }
    function clearAll() {
        history.clear(NotificationManager.Notifications.ClearExpired);
        for (let i = history.count - 1; i >= 0; --i) history.close(history.index(i, 0));
    }

    function ago(when) {
        if (!when) return "";
        const s = Math.max(0, (data.now - when.getTime()) / 1000);
        if (s < 60) return "Just now";
        if (s < 3600) return Math.floor(s / 60) + " min ago";
        if (s < 86400) return Math.floor(s / 3600) + " h ago";
        const d = Math.floor(s / 86400);
        return d === 1 ? "Yesterday" : d + " days ago";
    }
}
