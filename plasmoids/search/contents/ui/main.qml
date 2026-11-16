// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Search: a pill or icon that opens the start menu ready to type, or a
// search box like Windows' that you type into right on the taskbar, with the
// results in a panel above it -- part of Tidewater.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"
// ~/.local/share/tidewater/qml (install.sh puts it there): Tidewater's
// settings, shared by every Tidewater widget.
import "../../../../../tidewater/qml"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    // Search turned off in Tidewater's settings: hidden from the panel
    // altogether (a widget with no size still gets the panel's gap on each
    // side). Set by hand, not bound: typing in the box changes the status too.
    readonly property bool turnedOff: Settings.searchStyle === "hidden"
    onTurnedOffChanged: Plasmoid.status = turnedOff ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.PassiveStatus
    Component.onCompleted: if (turnedOff) Plasmoid.status = PlasmaCore.Types.HiddenStatus
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

    Palette { id: design }
    Exec { id: exec }
    fullRepresentation: Item {}
    // The search box never opens as a Plasma popup: Plasma would mark it with
    // its "open" line (in the highlight color) along the top of the panel.
    // A key press on the widget (Space, Enter) can ask for that; refuse it.
    activationTogglesExpanded: false
    onExpandedChanged: if (expanded) expanded = false
    // no tooltip on the search box, like Windows (it would also sit over the
    // results while you type); the plain button keeps "Search"
    toolTipMainText: Settings.searchStyle === "bar" ? "" : "Search"

    compactRepresentation: Item {
        NoOpenLine {}   // no Plasma "open" line over the panel (common/NoOpenLine.qml)
        // Hidden in Tidewater's settings: no size and nothing drawn, so the
        // panel closes up around it (Plasma's own Remove still works too).
        // "visible" goes on the content, not on this item: Plasma sets this
        // item's visible itself when it shows the widget.
        readonly property bool shown: Settings.searchStyle !== "hidden"
        readonly property bool bar: Settings.searchStyle === "bar"
        readonly property real w: bar ? searchBar.width : item.implicitWidth
        Layout.minimumWidth: shown ? w : 0
        Layout.preferredWidth: shown ? w : 0
        Layout.maximumWidth: shown ? w : 0
        Layout.fillHeight: true
        // Open the start menu ready to type in, like the search on Windows;
        // KRunner if there is no Tidewater start button.
        function open() {
            if (!Settings.openStartSearch(Plasmoid.containment ? Plasmoid.containment.screen : -1))
                exec.run("busctl --user call org.kde.krunner /App org.kde.krunner.App display");
        }

        BarButton {
            id: item
            visible: parent.shown && !parent.bar
            anchors.centerIn: parent
            pal: design
            // a pill with "Search", like Windows; just the icon has no frame
            // until hovered
            filled: Settings.searchStyle === "full"
            glyph: "search"
            svg: "search"     // the user's own magnifier (common/Glyph.qml)
            fallback: "search"
            // "full": the icon and "Search"; "icon": just the icon
            text: Settings.searchStyle === "full" ? "Search" : ""
            onClicked: parent.open()
        }

        // ---- "bar": a search box you type into, like the one on Windows ----------
        // While you type, the panel takes keyboard input (Plasma's "accepting
        // input" status) and the results show in a panel above the box. That
        // panel never takes the keyboard, so the typing stays in the box. The
        // search itself (apps, files, actions) and opening a result are the
        // start widget's, the same as in the start menu.
        readonly property var owner: Settings.searchOwner(Plasmoid.containment ? Plasmoid.containment.screen : -1)
        property string query: ""
        property int selected: 0
        property bool typing: false      // between startTyping() and stopTyping()
        property string tab: "all"       // the panel's filter: all, apps, documents, folders, settings
        onTabChanged: selected = 0
        readonly property var results: owner && query.trim().length > 0 ? owner.searchIn(query, tab) : []
        function startTyping() {
            typing = true;
            Plasmoid.status = PlasmaCore.Types.AcceptingInputStatus;
            field.forceActiveFocus();
            Qt.callLater(() => field.forceActiveFocus());   // after the panel takes the keyboard
        }
        // The box lets go of the keyboard: to the panel itself, not to Plasma's
        // wrapper around this widget (that would hand it straight back).
        function dropFocus() {
            field.focus = false;
            const win = searchBar.Window.window;
            if (win && win.contentItem && field.activeFocus) win.contentItem.forceActiveFocus();
        }
        function stopTyping() {
            typing = false;
            tab = "all";
            field.text = "";
            dropFocus();
            Plasmoid.status = PlasmaCore.Types.PassiveStatus;
        }
        function activate(item) {
            if (!item || !owner) return;
            if (item.kind === "app" || item.kind === "setting") owner.launch(item.id);
            else if (item.kind === "file") owner.openUrl(item.url);
            else if (item.kind === "action") owner.session(item.id);
            stopTyping();
        }

        // A click anywhere else on the taskbar ends the typing, like Windows.
        // (Clicking empty space or another widget's button does not move the
        // keyboard, so the box would not notice.) While typing, this lies
        // over the whole panel, ends the typing on a press outside the box,
        // and lets the press through to whatever is underneath.
        Item {
            id: clickCatcher
            readonly property Item panelRoot: searchBar.Window.window ? searchBar.Window.window.contentItem : null
            parent: searchBar.parent.typing && panelRoot ? panelRoot : searchBar.parent
            anchors.fill: parent
            z: 100000
            visible: searchBar.parent.typing
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    const p = mapToItem(searchBar, mouse.x, mouse.y);
                    if (!searchBar.contains(p))
                        searchBar.parent.stopTyping();
                    mouse.accepted = false;      // the press goes on to what is underneath
                }
            }
        }

        Rectangle {
            id: searchBar
            visible: parent.shown && parent.bar
            anchors.centerIn: parent
            width: Math.round(220 * design.unit)
            height: Math.max(22, Math.round(44 * design.unit))
            radius: height / 2
            // typing, like Windows: darker, a grey outline and a blue
            // magnifier (no blue outline)
            color: searchBar.parent.typing ? (design.dark ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 1))
                 : design.dark ? Qt.rgba(1, 1, 1, barArea.containsMouse ? 0.11 : 0.07)
                               : Qt.rgba(1, 1, 1, barArea.containsMouse ? 0.95 : 0.75)
            border.width: 1
            border.color: searchBar.parent.typing ? design.alpha(design.fg, 0.28) : design.stroke
            Behavior on color { ColorAnimation { duration: 120 } }
            Glyph {
                id: lens
                x: Math.round(searchBar.height * 0.42)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"; svg: "search"; fallback: "search"
                size: Math.max(14, Math.round(18 * design.unit))
                color: searchBar.parent.typing ? design.blue : design.fg
                fontAvailable: design.hasIconFont
            }
            QQC2.TextField {
                id: field
                anchors.left: lens.right
                anchors.leftMargin: Math.round(6 * design.unit)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(searchBar.height * 0.4)
                anchors.verticalCenter: parent.verticalCenter
                background: null
                // Only takes the keyboard while you are searching. Plasma hands
                // the keyboard to the first text box it finds in the panel
                // (when the panel gets it, and when this widget lets go of it),
                // which left a blinking cursor here while you typed elsewhere.
                activeFocusOnTab: false
                cursorVisible: activeFocus && searchBar.parent.typing
                color: design.text1
                selectionColor: design.blue
                selectedTextColor: design.blueText
                font.family: design.font
                font.pixelSize: Math.max(12, Math.round(14 * Math.min(1, Math.max(0.85, design.unit))))
                placeholderText: "Search"
                placeholderTextColor: design.mut
                onTextChanged: {
                    const box = searchBar.parent;
                    box.query = text;
                    box.selected = 0;
                    if (box.owner) box.owner.searchFiles(text);
                }
                // Lost the keyboard: clicked somewhere else, so stop typing. Not
                // when the results panel got it (handed back, see below).
                onActiveFocusChanged: if (activeFocus && !searchBar.parent.typing) {
                    // given the keyboard without being clicked: pass it on
                    Qt.callLater(searchBar.parent.dropFocus);
                } else if (!activeFocus) Qt.callLater(() => {
                    if (!field.activeFocus && !resultsPopup.active && searchBar.parent.typing)
                        searchBar.parent.stopTyping();
                })
                Keys.onDownPressed: searchBar.parent.selected = Math.max(0, Math.min(searchBar.parent.results.length - 1, searchBar.parent.selected + 1))
                Keys.onUpPressed: searchBar.parent.selected = Math.max(0, searchBar.parent.selected - 1)
                Keys.onReturnPressed: searchBar.parent.activate(searchBar.parent.results[searchBar.parent.selected])
                Keys.onEnterPressed: searchBar.parent.activate(searchBar.parent.results[searchBar.parent.selected])
                Keys.onEscapePressed: searchBar.parent.stopTyping()
            }
            // Until you are typing, a click anywhere on the box (above the text
            // field) starts typing: the panel has to be asked for the keyboard.
            MouseArea {
                id: barArea
                anchors.fill: parent
                enabled: !searchBar.parent.typing
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (searchBar.parent.owner) searchBar.parent.startTyping();
                    else searchBar.parent.open();     // no start button: KRunner
                }
            }
        }

        // ---- the results, above the box ----
        PlasmaCore.Dialog {
            id: resultsPopup
            // the same kind of window as the taskbar's preview card: it takes
            // clicks but not the keyboard
            type: PlasmaCore.Dialog.Tooltip
            flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
            location: PlasmaCore.Types.Floating
            backgroundHints: PlasmaCore.Dialog.StandardBackground
            visible: searchBar.visible && searchBar.parent.typing
            // If the window system gives the results the keyboard anyway, hand
            // it straight back to the box, so the typing goes on there.
            onActiveChanged: if (active) {
                searchBar.Window.window.requestActivate();
                field.forceActiveFocus();
            }
            onVisibleChanged: if (visible) Qt.callLater(place)
            onWidthChanged: if (visible) place()
            onHeightChanged: if (visible) place()
            // above the box, its left edge lined up with the box, kept on the
            // panel's monitor
            function place() {
                const g = Plasmoid.containment.screenGeometry;
                const p = searchBar.mapToGlobal(0, 0);
                const w = list.width + (margins ? margins.left + margins.right : 0);
                const h = list.height + (margins ? margins.top + margins.bottom : 0);
                x = Math.max(g.x + 8, Math.min(g.x + g.width - w - 8, Math.round(p.x)));
                y = Math.max(g.y + 8, Math.round(p.y - h - 10));
            }

            mainItem: SearchPanel {
                id: list
                box: searchBar.parent
                pal: design
            }
        }
    }
}
