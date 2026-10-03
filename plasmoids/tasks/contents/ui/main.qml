// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Icon taskbar: the active app on a light accent
// pill, a short accent bar under it, a dot per open window under the others.
// Window data comes from Plasma's own task model (the one its taskbar uses).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import "common"
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings, shared by every Tidewater widget.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea

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

    Palette {
        id: design
    }

    // No Plasma widget tooltip here: it fought with the preview card.
    toolTipMainText: ""
    toolTipSubText: ""

    TaskManager.VirtualDesktopInfo {
        id: desktops
    }
    TaskManager.ActivityInfo {
        id: activities
    }

    TaskManager.TasksModel {
        id: tasks
        virtualDesktop: desktops.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activities.currentActivity
        // Same apps on every desktop unless you turn that off in Tidewater's settings.
        filterByVirtualDesktop: !Settings.showAllDesktops
        filterByActivity: true
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
    }

    // Pins can change from outside (the start menu's "Pin to taskbar"):
    // follow the saved list whenever it differs from what's shown.
    readonly property var savedLaunchers: Plasmoid.configuration.launchers
    onSavedLaunchersChanged: {
        if (String(tasks.launcherList) !== String(savedLaunchers))
            tasks.launcherList = savedLaunchers;
    }

    // These options used to be saved in this taskbar's own settings. Hand them
    // to the start widget, which moves them into Tidewater's settings once.
    Component.onCompleted: Settings.offerLegacy("tasks", {
        alignment: Plasmoid.configuration.alignment,
        iconSize: Plasmoid.configuration.iconSize,
        expand: Plasmoid.configuration.expand,
        showAllDesktops: Plasmoid.configuration.showAllDesktops
    })

    // sized from the bar thickness (52); icon size and alignment are Tidewater's settings
    readonly property real k: Math.max(0.7, design.unit)
    readonly property int iconSize: Settings.iconSize
    readonly property int buttonHeight: Math.min(48, Math.max(Math.round(48 * design.unit), iconSize + 12))
    readonly property bool alignLeft: Settings.alignment === "left"
    readonly property int pad: Math.round(12 * k)
    readonly property int spacing: Math.max(2, Math.round(6 * design.unit))

    // ---- window previews (hover card) ----------------------------
    property var hoveredTask: null
    property var previewWindows: []
    // True while the card is open because an app with several windows was
    // clicked (not just hovered). A second click on that app closes it again.
    property bool cardByClick: false
    // Goes up on every change in the task model, also changes inside a group
    // (another window of the same app getting focus). Bindings that read
    // windows of a group mention it, so they are worked out again.
    property int modelRev: 0

    // ---- drag to reorder -------------------------------------------
    // The drag lives here, not in a delegate: moving a row in Plasma's task
    // model can re-sort or rebuild delegates, and a MouseArea inside the
    // dragged delegate loses its grab (or ends up driving a different app).
    // We track the dragged app by a stable key and look its row up each time.
    property string dragKey: ""
    readonly property bool dragging: dragKey !== ""

    function keyFor(url, winIds) {
        return String(url || "") + "|" + (winIds && winIds.length ? String(winIds[0]) : "");
    }
    function keyAt(i) {
        const idx = tasks.makeModelIndex(i);
        return keyFor(tasks.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon), tasks.data(idx, TaskManager.AbstractTasksModel.WinIdList));
    }
    function rowOfKey(key) {
        for (let i = 0; i < tasks.count; ++i)
            if (keyAt(i) === key)
                return i;
        return -1;
    }
    // Row of the app being dragged. If its key changed mid-drag (e.g. the
    // group's first window closed), find it again by its launcher and follow it.
    function dragRow() {
        let row = rowOfKey(dragKey);
        if (row < 0) {
            const url = dragKey.split("|")[0];
            for (let i = 0; url && i < tasks.count; ++i)
                if (keyAt(i).split("|")[0] === url) {
                    row = i;
                    break;
                }
            if (row >= 0)
                dragKey = keyAt(row);
        }
        return row;
    }

    function hoverTask(t) {
        if (dragging)
            return;
        // a card opened by a click turns into a plain hover card on another app
        if (t !== hoveredTask)
            cardByClick = false;
        hoveredTask = t;
        closeTimer.stop();
        if (preview.visible)
            fillPreview();
        else
            openTimer.restart();
    }
    // Qt can report entering the next icon before leaving the previous one:
    // a late leave from an icon that is no longer the hovered one is ignored.
    function leaveTask(t) {
        if (t !== hoveredTask)
            return;
        openTimer.stop();
        closeTimer.restart();
    }
    function hidePreview() {
        openTimer.stop();
        closeTimer.stop();
        preview.visible = false;
    }
    // Click on an app with several windows: show its card straight away (no
    // hover delay) so a window can be picked from it. Clicking the same app
    // again closes the card.
    function toggleGroupCard(t) {
        if (preview.visible && hoveredTask === t && cardByClick) {
            hidePreview();
            return;
        }
        hoveredTask = t;
        openTimer.stop();
        closeTimer.stop();
        fillPreview();
        if (previewWindows.length === 0)
            return;
        cardByClick = true;
        preview.visible = true;
    }
    // Where a window is in the model *now* (rows shift as other apps open and
    // close, so a row saved when the card opened can point at another app).
    function indexOfWin(winId) {
        const R = TaskManager.AbstractTasksModel;
        const has = idx => (tasks.data(idx, R.WinIdList) || []).some(w => String(w) === winId);
        for (let i = 0; i < tasks.count; ++i) {
            const parent = tasks.makeModelIndex(i);
            if (!has(parent))
                continue;
            const n = tasks.rowCount(parent);
            for (let j = 0; j < n; ++j) {
                const child = tasks.makeModelIndex(i, j);
                if (has(child))
                    return child;
            }
            return parent;
        }
        return null;
    }
    function activateWin(winId) {
        const idx = indexOfWin(winId);
        if (idx)
            tasks.requestActivate(idx);
    }
    function closeWin(winId) {
        const idx = indexOfWin(winId);
        if (idx)
            tasks.requestClose(idx);
    }
    // keep the open card in step with windows opening, closing or renaming
    // (and the active window dots in step with focus moving between windows)
    Connections {
        target: tasks
        function onRowsRemoved() {
            root.modelRev++;
            if (preview.visible)
                Qt.callLater(root.fillPreview);
        }
        function onRowsInserted() {
            root.modelRev++;
            if (preview.visible)
                Qt.callLater(root.fillPreview);
        }
        function onDataChanged() {
            root.modelRev++;
            if (preview.visible)
                Qt.callLater(root.fillPreview);
        }
    }

    function fillPreview() {
        const t = hoveredTask;
        if (!t || !t.model) {
            preview.visible = false;
            return;
        }
        const ids = t.model.WinIdList || [];
        const list = [];
        for (let i = 0; i < ids.length; ++i) {
            const idx = t.isGroup ? tasks.makeModelIndex(t.index, i) : tasks.makeModelIndex(t.index);
            list.push({
                winId: String(ids[i]),
                idx: idx,
                title: tasks.data(idx, Qt.DisplayRole) || t.model.AppName || "",
                minimized: tasks.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true
            });
        }
        if (list.length === 0) {
            preview.visible = false;
            previewWindows = [];
            return;
        }
        // only swap the list when something shown changed: swapping rebuilds the
        // thumbnails, which would flicker on every title or focus change
        const sig = l => JSON.stringify(l.map(w => [w.winId, w.title, w.minimized]));
        if (sig(list) !== sig(previewWindows))
            previewWindows = list;
    }
    Timer {
        id: openTimer
        interval: 500
        onTriggered: {
            root.fillPreview();
            if (root.previewWindows.length > 0)
                preview.visible = true;
        }
    }
    // A card opened by a click gets a little longer to reach before it closes.
    Timer {
        id: closeTimer
        interval: root.cardByClick ? 600 : 300
        onTriggered: if (!cardHover.hovered)
            preview.visible = false
    }

    // The card never gets wider than most of the screen: past that, the
    // last cell says how many more windows there are.
    readonly property real cardMaxWidth: {
        const w = Plasmoid.containment.screenGeometry.width;
        return w > 0 ? Math.round(w * 0.8) : 1600;
    }
    readonly property int cellWidth: 176 + 16
    readonly property int cellSpacing: 10
    readonly property int maxCells: Math.max(1, Math.floor((cardMaxWidth - 28 + cellSpacing) / (cellWidth + cellSpacing)))
    // how many windows get a cell; the rest are counted in the "+N more" cell
    readonly property int shownCells: previewWindows.length > maxCells ? maxCells - 1 : previewWindows.length

    PlasmaCore.Dialog {
        id: preview
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        location: Plasmoid.location
        visualParent: root.hoveredTask
        // Plasma's own frame (with KWin's shadow and blur). A card drawn by
        // hand on a frameless (NoBackground) popup never showed up on Wayland.
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        visible: false
        onVisibleChanged: if (!visible)
            root.cardByClick = false

        mainItem: Item {
            id: cardWindow
            width: card.width
            height: card.height
            HoverHandler {
                id: cardHover
                onHoveredChanged: if (!hovered)
                    closeTimer.restart()
                else
                    closeTimer.stop()
            }

            Item {
                id: card
                width: Math.min(root.cardMaxWidth, Math.max(header.implicitWidth, cells.implicitWidth) + 28)
                height: header.height + cells.height + 38

                Row {
                    id: header
                    x: 14
                    y: 12
                    spacing: 12
                    height: 40
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        source: root.hoveredTask ? root.hoveredTask.model.decoration : ""
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            // a long name is cut short to fit the card (36 icon + 12 gap)
                            width: Math.min(implicitWidth, root.cardMaxWidth - 28 - 48)
                            elide: Text.ElideRight
                            text: root.hoveredTask ? (root.hoveredTask.model.AppName || root.hoveredTask.model.display || "") : ""
                            textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                            font.family: design.font
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: design.fg
                        }
                        Text {
                            text: root.previewWindows.length > 1 ? root.previewWindows.length + " windows" : "1 window"
                            font.family: design.font
                            font.pixelSize: 12
                            color: design.mut
                        }
                    }
                }

                Row {
                    id: cells
                    x: 14
                    anchors.top: header.bottom
                    anchors.topMargin: 12
                    spacing: root.cellSpacing
                    Repeater {
                        model: root.previewWindows.slice(0, root.shownCells)
                        Rectangle {
                            id: cell
                            required property var modelData
                            width: root.cellWidth
                            height: 99 + 44
                            radius: 6
                            color: cellArea.containsMouse ? design.accC : "transparent"

                            Rectangle {
                                id: shot
                                x: 8
                                y: 8
                                width: 176
                                height: 99
                                radius: 4
                                color: design.s2
                                clip: true
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 40
                                    visible: !thumb.item || !thumb.item.hasThumbnail
                                    source: root.hoveredTask ? root.hoveredTask.model.decoration : ""
                                }
                                Loader {
                                    id: thumb
                                    anchors.fill: parent
                                    active: preview.visible && !cell.modelData.minimized
                                    source: "Thumbnail.qml"
                                    onLoaded: item.winId = cell.modelData.winId
                                }
                            }
                            Text {
                                anchors.top: shot.bottom
                                anchors.topMargin: 8
                                x: 8
                                width: 176
                                elide: Text.ElideRight
                                text: cell.modelData.title
                                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                font.family: design.font
                                font.pixelSize: 12
                                color: cellArea.containsMouse ? design.accCFg : design.fg
                            }
                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activateWin(cell.modelData.winId);
                                    preview.visible = false;
                                }
                            }
                            Rectangle {
                                anchors.right: shot.right
                                anchors.top: shot.top
                                anchors.margins: 4
                                width: 22
                                height: 22
                                radius: 11
                                visible: cellArea.containsMouse || closeArea.containsMouse
                                color: closeArea.containsMouse ? design.s3 : design.s2
                                Glyph {
                                    anchors.centerIn: parent
                                    name: "close"
                                    fallback: "window-close"
                                    size: 14
                                    color: design.fg
                                    fontAvailable: design.hasIconFont
                                }
                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closeWin(cell.modelData.winId);
                                        // the card refreshes itself once the window is really gone
                                        if (root.previewWindows.length <= 1)
                                            preview.visible = false;
                                    }
                                }
                            }
                        }
                    }
                    // Too many windows to show: say how many more there are.
                    Item {
                        visible: root.shownCells < root.previewWindows.length
                        width: root.cellWidth
                        height: 99 + 44
                        Text {
                            anchors.centerIn: parent
                            text: "+" + (root.previewWindows.length - root.shownCells) + " more"
                            font.family: design.font
                            font.pixelSize: 15
                            color: design.mut
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: Item {
        id: strip
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.fillHeight: true
        // Fill the bar so the icons can sit left, or centered on the screen.
        Layout.fillWidth: Settings.expand

        // Centered means centered on the screen (like Windows), not in this strip.
        property real centerX: 0
        function place() {
            const screen = Plasmoid.containment.screenGeometry;
            const here = strip.mapToGlobal(0, 0).x;
            const want = screen.x + (screen.width - row.width) / 2 - here;
            centerX = Math.max(0, Math.min(strip.width - row.width, want));
        }
        onWidthChanged: Qt.callLater(place)
        // resolution/scale changes or moving to another screen keep our width
        readonly property rect screenGeo: Plasmoid.containment.screenGeometry
        onScreenGeoChanged: Qt.callLater(place)
        onXChanged: Qt.callLater(place)
        Component.onCompleted: Qt.callLater(place)
        Connections {
            target: row
            function onWidthChanged() {
                Qt.callLater(strip.place);
            }
        }
        Timer {
            interval: 1500
            running: true
            onTriggered: strip.place()
        }

        // Right-click on an empty spot: Tidewater's settings (they live with
        // the start button). Without a start button, Plasma's own menu instead.
        // Left click on an empty spot closes the window card.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | (Settings.canOpen ? Qt.RightButton : Qt.NoButton)
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.hidePreview();
                else
                    stripMenu.open(mouse.x, mouse.y);
            }
            PlasmaExtras.Menu {
                id: stripMenu
                visualParent: strip
                PlasmaExtras.MenuItem {
                    text: "Tidewater settings..."
                    icon: "configure"
                    onClicked: Settings.openSettings()
                }
            }
        }

        Row {
            id: row
            // Always left to right, also in right-to-left languages: the drag
            // maths below count slots from the left.
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true
            anchors.verticalCenter: parent.verticalCenter
            x: root.alignLeft || !Settings.expand ? 0 : strip.centerX
            Behavior on x {
                NumberAnimation {
                    duration: 150
                }
            }
            spacing: root.spacing

            Repeater {
                model: tasks

                delegate: Item {
                    id: task
                    required property var model
                    required property int index

                    readonly property var modelIndex: tasks.makeModelIndex(index)
                    readonly property bool isLauncher: model.IsLauncher === true
                    readonly property bool isActive: model.IsActive === true
                    readonly property bool isGroup: model.IsGroupParent === true
                    readonly property int windowCount: isLauncher ? 0 : (isGroup ? model.ChildCount : 1)
                    // Pinned apps not running get Plasma's tooltip, which sits on
                    // top and takes the hover from area: count both.
                    readonly property bool hovered: area.containsMouse || (isLauncher && tip.containsMouse)
                    onHoveredChanged: {
                        if (hovered && !isLauncher)
                            root.hoverTask(task);
                        else
                            // a late leave is ignored there; entering a pinned app
                            // (no card of its own) closes the card of the last one
                            root.leaveTask(hovered ? root.hoveredTask : task);
                    }
                    readonly property string key: root.keyFor(model.LauncherUrlWithoutIcon, model.WinIdList)
                    readonly property bool beingDragged: root.dragging && root.dragKey === key

                    // Which dot (one per window, at most 4) is the long bar: the
                    // one of the window that has focus, -1 when none has it.
                    // With more windows than dots, a focused window past the
                    // last dot puts the bar on the last dot.
                    readonly property int activeDot: {
                        root.modelRev;   // read again when focus moves inside the group
                        if (!isActive || windowCount < 1)
                            return -1;
                        if (!isGroup)
                            return 0;
                        const dots = Math.min(4, windowCount);
                        for (let i = 0; i < windowCount; ++i) {
                            const child = tasks.makeModelIndex(index, i);
                            if (tasks.data(child, TaskManager.AbstractTasksModel.IsActive) === true)
                                return Math.min(i, dots - 1);
                        }
                        return 0;   // the app is active but no window says so yet
                    }

                    // Left click (the drag layer above the row forwards it here).
                    // An app with several windows opens its card to pick one from.
                    function leftClick() {
                        if (task.isGroup) {
                            root.toggleGroupCard(task);
                            return;
                        }
                        root.hidePreview();
                        if (task.isActive) {
                            tasks.requestToggleMinimized(task.modelIndex);
                        } else {
                            tasks.requestActivate(task.modelIndex);
                        }
                    }

                    width: root.iconSize + 2 * root.pad
                    height: root.buttonHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(14 * root.k)
                        color: task.isActive ? design.accC : task.hovered ? design.s2 : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        // demands attention
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: design.r.warning
                            opacity: task.model.IsDemandingAttention ? 0.25 : 0
                        }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        scale: task.beingDragged ? 1.12 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                        width: root.iconSize
                        height: root.iconSize
                        source: task.model.decoration
                        opacity: task.model.IsStartup ? 0.5 : 1
                    }

                    // Under the button: a dot per window, the focused window's dot
                    // drawn as a long accent bar.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 1
                        spacing: 3
                        Repeater {
                            model: Math.min(4, task.windowCount)
                            Rectangle {
                                required property int index
                                readonly property bool focused: index === task.activeDot
                                width: focused ? Math.round(22 * root.k) : 3
                                height: 3
                                radius: 1.5
                                color: focused ? design.acc : design.alpha(design.fg, 0.4)
                            }
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        // Left button is handled by the drag layer above the row.
                        acceptedButtons: Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            root.hidePreview();
                            if (mouse.button === Qt.RightButton)
                                menu.openRelative();
                            else if (mouse.button === Qt.MiddleButton)
                                tasks.requestNewInstance(task.modelIndex);
                        }
                    }

                    // Plasma's own tooltip and menu: they open as windows of their own,
                    // so they aren't squeezed into the panel.
                    PlasmaCore.ToolTipArea {
                        id: tip
                        anchors.fill: parent
                        // hidden (not just inactive) on windows so it can't eat their hover
                        visible: task.isLauncher
                        active: task.isLauncher
                        mainText: task.model.display || task.model.AppName || ""
                        location: Plasmoid.location
                    }

                    PlasmaExtras.Menu {
                        id: menu
                        visualParent: task
                        // open away from the panel edge
                        placement: {
                            switch (Plasmoid.location) {
                            case PlasmaCore.Types.TopEdge:
                                return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
                            case PlasmaCore.Types.LeftEdge:
                                return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                            case PlasmaCore.Types.RightEdge:
                                return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
                            default:
                                return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
                            }
                        }
                        PlasmaExtras.MenuItem {
                            text: "New window"
                            icon: "window-new"
                            onClicked: tasks.requestNewInstance(task.modelIndex)
                        }
                        PlasmaExtras.MenuItem {
                            text: task.model.HasLauncher === true ? "Unpin from taskbar" : "Pin to taskbar"
                            icon: task.model.HasLauncher === true ? "window-unpin" : "window-pin"
                            onClicked: task.model.HasLauncher === true ? tasks.requestRemoveLauncher(task.model.LauncherUrlWithoutIcon) : tasks.requestAddLauncher(task.model.LauncherUrl)
                        }
                        PlasmaExtras.MenuItem {
                            separator: true
                            visible: !task.isLauncher
                        }
                        PlasmaExtras.MenuItem {
                            visible: !task.isLauncher
                            text: task.isGroup ? "Close all windows" : "Close window"
                            icon: "window-close"
                            onClicked: tasks.requestClose(task.modelIndex)
                        }
                    }
                }
            }
        }

        // Left button layer over the icons: click to activate, drag sideways to
        // reorder. Hover, middle and right clicks fall through to the icons.
        MouseArea {
            id: dragLayer
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true
            x: row.x
            y: row.y
            width: row.width
            height: row.height
            acceptedButtons: Qt.LeftButton
            hoverEnabled: false
            preventStealing: true   // don't let the panel take the grab mid-drag
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

            property real pressX: 0
            property string pressKey: ""

            function taskAt(x, y) {
                const item = row.childAt(x, y);
                return item && item.key !== undefined ? item : null;
            }
            function finish(commit) {
                if (!root.dragging)
                    return false;
                root.dragKey = "";
                if (commit)
                    tasks.syncLaunchers();   // keep pinned apps in the new order
                return true;
            }

            onPressed: mouse => {
                const t = taskAt(mouse.x, mouse.y);
                pressX = mouse.x;
                pressKey = t ? t.key : "";
                if (!t)
                    mouse.accepted = false;
            }
            onPositionChanged: mouse => {
                if (!pressKey)
                    return;
                if (!root.dragging) {
                    if (Math.abs(mouse.x - pressX) < 10)
                        return;
                    root.hidePreview();
                    root.dragKey = pressKey;
                }
                const from = root.dragRow();
                if (from < 0)
                    return;
                const slot = root.iconSize + 2 * root.pad + root.spacing;
                const target = Math.max(0, Math.min(tasks.count - 1, Math.floor(mouse.x / slot)));
                if (target !== from)
                    tasks.move(from, target);
            }
            onReleased: mouse => {
                const wasDrag = finish(true);
                const key = pressKey;
                pressKey = "";
                if (wasDrag)
                    return;
                const t = taskAt(mouse.x, mouse.y);
                if (t && t.key === key)
                    t.leftClick();
            }
            onCanceled: {
                finish(true);
                pressKey = "";
            }
        }
    }
}
