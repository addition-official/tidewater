// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Workspace pills: the current desktop in the
// accent, desktops with windows on them in gray, empty ones bare.
// Tidewater's settings choose numbered pills (the default), small dots, or
// nothing at all.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
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
    fullRepresentation: Item {}
    toolTipMainText: "Workspaces"

    Palette { id: design }
    Exec { id: exec }

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    // Every window, unfiltered, to see which desktops are occupied.
    TaskManager.TasksModel {
        id: allTasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: true
        activity: activities.currentActivity
        onCountChanged: root.recount()
        onDataChanged: root.recount()
    }

    property var occupied: ({})
    function recount() {
        const occ = {};
        for (let i = 0; i < allTasks.count; ++i) {
            const idx = allTasks.makeModelIndex(i);
            if (allTasks.data(idx, TaskManager.AbstractTasksModel.IsLauncher)) continue;
            if (allTasks.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)) continue;
            const ds = allTasks.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
            for (const d of ds) occ[String(d)] = true;
        }
        occupied = occ;
    }
    Component.onCompleted: recount()

    // The desktop we last asked KWin for. currentDesktop only changes a moment
    // later, so quick wheel events step on from here instead of from the old
    // desktop. Forgotten once KWin switches (or after a second if it never does).
    property int pendingIndex: -1
    Connections {
        target: desktops
        function onCurrentDesktopChanged() { root.pendingIndex = -1; }
        function onDesktopIdsChanged() { root.pendingIndex = -1; }
    }
    Timer { id: pendingReset; interval: 1000; onTriggered: root.pendingIndex = -1 }

    function activate(id) {
        pendingIndex = desktops.desktopIds.indexOf(id);
        pendingReset.restart();
        exec.run("busctl --user set-property org.kde.KWin /VirtualDesktopManager "
                 + "org.kde.KWin.VirtualDesktopManager current s " + exec.q(String(id)));
    }
    function step(delta) {
        const ids = desktops.desktopIds;
        const cur = root.pendingIndex >= 0 && root.pendingIndex < ids.length ? root.pendingIndex
                                                                            : ids.indexOf(desktops.currentDesktop);
        const next = Math.max(0, Math.min(ids.length - 1, cur + delta));
        if (next !== cur) activate(ids[next]);
    }

    readonly property int pillSize: Math.max(18, Math.round(34 * design.unit))
    readonly property real k: Math.max(0.7, design.unit)
    readonly property bool dots: Settings.workspaces === "dots"
    // dots: a short pill per desktop, the current one longer and in the accent
    readonly property int dotSize: Math.max(6, Math.round(10 * k))

    compactRepresentation: Item {
        // Hidden in Tidewater's settings: no size and nothing drawn, so the
        // panel closes up around it (Plasma's own Remove still works too).
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.workspaces !== "hidden"
        Layout.minimumWidth: shown ? row.implicitWidth : 0
        Layout.preferredWidth: shown ? row.implicitWidth : 0
        Layout.maximumWidth: shown ? row.implicitWidth : 0
        Layout.fillHeight: true

        // One desktop per wheel notch (120), however finely the touchpad or
        // wheel reports it; sideways-only scrolling is ignored.
        WheelHandler {
            enabled: parent.shown
            property real acc: 0
            onWheel: event => {
                const d = event.angleDelta.y;
                if (d === 0) return;
                if ((acc > 0) !== (d > 0)) acc = 0;   // changed direction: start over
                acc += d;
                let n = 0;
                while (Math.abs(acc) >= 120) {
                    n += acc > 0 ? -1 : 1;
                    acc -= acc > 0 ? 120 : -120;
                }
                if (n !== 0) root.step(n);
            }
        }

        Row {
            id: row
            visible: parent.shown
            anchors.centerIn: parent
            spacing: root.dots ? 0 : Math.max(2, Math.round(5 * design.unit))

            Repeater {
                model: desktops.desktopIds

                Rectangle {
                    id: pill
                    required property var modelData
                    required property int index
                    readonly property bool active: String(modelData) === String(desktops.currentDesktop)
                    readonly property bool busy: root.occupied[String(modelData)] === true
                    readonly property bool hovered: area.containsMouse

                    // dots: a narrower click target, the same height as the pills
                    width: root.dots ? root.dotSize * (active ? 2.6 : 1) + Math.round(10 * root.k) : root.pillSize
                    height: root.pillSize
                    radius: Math.round(11 * root.k)
                    color: root.dots ? "transparent"
                         : active ? design.acc
                         : busy ? (hovered ? design.s3 : design.s2)
                         : hovered ? design.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 120 } }

                    // the dot: accent for the current desktop, stronger gray
                    // for desktops with windows, faint for empty ones
                    Rectangle {
                        visible: root.dots
                        anchors.centerIn: parent
                        width: root.dotSize * (pill.active ? 2.6 : 1)
                        height: root.dotSize
                        radius: height / 2
                        color: pill.active ? design.acc
                             : pill.hovered ? design.fg
                             : pill.busy ? design.mut : design.out
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        visible: !root.dots
                        anchors.centerIn: parent
                        text: pill.index + 1
                        font.family: design.font
                        font.pixelSize: 13
                        font.weight: pill.active ? Font.Medium : Font.Normal
                        color: pill.active ? design.accFg : design.mut
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(pill.modelData)
                    }
                }
            }
        }
    }
}
