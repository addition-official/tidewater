// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Workspace pills: the current desktop in the
// accent, desktops with windows on them in grey, empty ones bare.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import "common"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
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

    function activate(id) {
        exec.run("busctl --user set-property org.kde.KWin /VirtualDesktopManager "
                 + "org.kde.KWin.VirtualDesktopManager current s " + exec.q(String(id)));
    }
    function step(delta) {
        const ids = desktops.desktopIds;
        const cur = ids.indexOf(desktops.currentDesktop);
        const next = Math.max(0, Math.min(ids.length - 1, cur + delta));
        if (next !== cur) activate(ids[next]);
    }

    readonly property int pillSize: Math.max(18, Math.round(34 * design.unit))
    readonly property real k: Math.max(0.7, design.unit)

    compactRepresentation: Item {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.maximumWidth: row.implicitWidth
        Layout.fillHeight: true

        // One desktop per wheel notch (120), however finely the touchpad or
        // wheel reports it; sideways-only scrolling is ignored.
        WheelHandler {
            property real acc: 0
            onWheel: event => {
                const d = event.angleDelta.y;
                if (d === 0) return;
                if ((acc > 0) !== (d > 0)) acc = 0;   // changed direction: start over
                acc += d;
                while (Math.abs(acc) >= 120) {
                    root.step(acc > 0 ? -1 : 1);
                    acc -= acc > 0 ? 120 : -120;
                }
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.max(2, Math.round(5 * design.unit))

            Repeater {
                model: desktops.desktopIds

                Rectangle {
                    id: pill
                    required property var modelData
                    required property int index
                    readonly property bool active: String(modelData) === String(desktops.currentDesktop)
                    readonly property bool busy: root.occupied[String(modelData)] === true
                    readonly property bool hovered: area.containsMouse

                    width: root.pillSize
                    height: root.pillSize
                    radius: Math.round(11 * root.k)
                    color: active ? design.acc
                         : busy ? (hovered ? design.s3 : design.s2)
                         : hovered ? design.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
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
