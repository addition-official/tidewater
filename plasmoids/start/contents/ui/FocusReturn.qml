// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The window you were in gets the keyboard back when the start menu closes,
// like Windows: closing the menu without opening anything (Escape, the Start
// button, the Meta key) goes back to it.
//
// Plasma keeps no such memory for a popup: as the menu closes, KWin hands the
// keyboard to the last used window on the menu's monitor (the one the mouse
// is on), which can be another window, or one on the other monitor.
//
// Not when something was opened from the menu (it gets the keyboard), and not
// when the menu was closed by clicking another window or the desktop (the
// menu had already lost the keyboard then: what you clicked keeps it).
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: fr
    property bool handingOff: false     // something was opened from the menu
    property string lastActiveWin: ""   // the last window that had the keyboard
    property string focusBefore: ""     // the window to go back to

    // The menu opens: remember the window you are in.
    function remember() {
        handingOff = false;
        focusBefore = winOf(tasks.activeTask) || lastActiveWin;
    }
    // The menu closed; `hadKeyboard`: it still had the keyboard as it closed.
    function closed(hadKeyboard) {
        const want = focusBefore;
        focusBefore = "";
        if (!want || handingOff || !hadKeyboard)
            return;
        giveBack.win = want;
        giveBack.tries = 0;
        giveBack.interval = 60;
        giveBack.restart();
    }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
        // (the menu itself never shows here: Plasma's popups are not
        // taskbar windows)
        onActiveTaskChanged: { const id = fr.winOf(activeTask); if (id) fr.lastActiveWin = id; }
    }
    function winOf(idx) {
        if (!idx || !idx.valid) return "";
        const ids = tasks.data(idx, TaskManager.AbstractTasksModel.WinIdList) || [];
        return ids.length ? String(ids[0]) : "";
    }
    function taskOfWin(win) {
        for (let i = 0; i < tasks.count; ++i) {
            const idx = tasks.makeModelIndex(i);
            if ((tasks.data(idx, TaskManager.AbstractTasksModel.WinIdList) || []).some(w => String(w) === win))
                return idx;
        }
        return null;
    }
    // A moment after the menu goes (KWin picks its own window as the menu's
    // window closes), and once more in case that came later.
    Timer {
        id: giveBack
        property string win: ""
        property int tries: 0
        interval: 60
        onTriggered: {
            if (fr.winOf(tasks.activeTask) !== win) {
                const idx = fr.taskOfWin(win);
                if (idx) tasks.requestActivate(idx);   // closed meanwhile: leave it to KWin
            }
            if (++tries < 2) { interval = 200; restart(); }
        }
    }
}
