// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A live picture of one window, the way Plasma's own taskbar gets it:
// ask KWin for a screencast of the window, draw the PipeWire stream.
// Loaded through a Loader so a missing PipeWire module can't break the taskbar.
import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: thumbSource
    property string winId
    readonly property bool hasThumbnail: ready
    nodeId: request.nodeId
    TaskManager.ScreencastingRequest {
        id: request
        uuid: thumbSource.winId
    }
}
