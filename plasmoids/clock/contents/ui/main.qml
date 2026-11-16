// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Clock: time over date ("20:35 / Tue 15 Sep"), a soft pill on hover, and,
// like Windows 11, the unread notification count beside it. Clicked, it opens
// the notifications above a month calendar.
// Its options (seconds, 12/24-hour, the date line) are Tidewater's settings.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
    Palette {
        id: design
    }

    // ---- notifications (shown above the calendar) ----------------------------
    // Read state is shared with every other clock (and the bell, if it is on)
    // through ReadMark, and saved here so it survives a restart.
    NotificationData {
        id: notifs
        lastRead: ReadMark.lastRead
    }
    Connections {
        target: ReadMark
        function onLastReadChanged() {
            if (Plasmoid.configuration.lastRead !== ReadMark.lastRead)
                Plasmoid.configuration.lastRead = ReadMark.lastRead;
        }
    }
    // closing the popup marks everything shown in it as read
    onExpandedChanged: if (!root.expanded) ReadMark.offer(notifs.markRead())

    property date now: new Date()
    // Tick right after each second (or, with seconds hidden, at least every 5 s
    // and right after each minute), so the display never lags or skips.
    function nextDelay() {
        const t = Date.now();
        return root.showSeconds ? 1000 - t % 1000 + 20 : Math.min(5000, 60000 - t % 60000 + 20);
    }
    Timer {
        id: tick
        interval: root.nextDelay()
        running: true
        onTriggered: {
            root.now = new Date();
            interval = root.nextDelay();
            start();
        }
    }
    readonly property bool showSeconds: Settings.showSeconds
    onShowSecondsChanged: {
        now = new Date();
        tick.interval = nextDelay();
        tick.restart();
    }

    // 12- or 24-hour: "system" follows Region & Language; "24h"/"12h" override it.
    // Seconds are Tidewater's own option.
    readonly property string hourMode: Settings.hourMode || "system"
    readonly property string systemFormat: hourMode === "24h" ? "HH:mm" : hourMode === "12h" ? "h:mm AP" : Qt.locale().timeFormat(Locale.ShortFormat)
    readonly property string timeFormat: Settings.showSeconds && root.systemFormat.indexOf("ss") < 0 ? root.systemFormat.replace("mm", "mm:ss") : root.systemFormat

    toolTipMainText: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat))

    // The big date in the calendar ("November 8, 2026" or "8 November 2026"):
    // day and month in the same order as the panel's date format, so a
    // month-first choice like "ddd, MMM d" gives a month-first date here too.
    // If that format has no day or month, the order of Region & Language.
    function monthFirst(fmt) {
        // the parts outside 'quoted text'; a day is d or dd (ddd/dddd is the weekday)
        const parts = String(fmt || "").replace(/'[^']*'/g, "").match(/d+|M+/g) || [];
        const day = parts.findIndex(t => t[0] === "d" && t.length <= 2);
        const month = parts.findIndex(t => t[0] === "M");
        return day >= 0 && month >= 0 ? month < day : null;
    }
    readonly property string longDateFormat: {
        let first = monthFirst(Settings.dateFormat);
        if (first === null)
            first = monthFirst(Qt.locale().dateFormat(Locale.LongFormat)) === true;
        return first ? "MMMM d, yyyy" : "d MMMM yyyy";
    }

    // These options used to be saved in this clock's own settings. Hand them
    // to the start widget, which moves them into Tidewater's settings once.
    Component.onCompleted: {
        Settings.offerLegacy("clock", {
            showSeconds: Plasmoid.configuration.showSeconds,
            showDate: Plasmoid.configuration.showDate,
            hourMode: Plasmoid.configuration.hourMode,
            dateFormat: Plasmoid.configuration.dateFormat
        });
        ReadMark.offer(Plasmoid.configuration.lastRead);
    }
    readonly property real k: Math.max(0.7, design.unit)

    compactRepresentation: Item {
        Layout.minimumWidth: face.width
        Layout.preferredWidth: face.width
        Layout.maximumWidth: face.width
        Layout.fillHeight: true

        Rectangle {
            id: face
            anchors.centerIn: parent
            width: Math.max(time.implicitWidth, date.visible ? date.implicitWidth : 0) + Math.round(24 * root.k)
                   + (badge.visible ? badge.width + Math.round(8 * root.k) : 0)
            height: design.thickness - 8
            radius: Math.round(13 * root.k)
            color: area.containsMouse || root.expanded ? design.s2 : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Column {
                id: clockText
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(12 * root.k)
                spacing: 0
                Text {
                    id: time
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, root.timeFormat)
                    font.features: {
                        "tnum": 1
                    }   // equal-width digits: no wobble as seconds tick
                    font.family: design.font
                    font.pixelSize: Math.round(14 * Math.min(1, Math.max(0.9, design.unit)))
                    font.weight: Font.Medium
                    color: design.fg
                }
                Text {
                    id: date
                    visible: Settings.showDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.now, Settings.dateFormat || "ddd d MMM")
                    font.family: design.font
                    font.pixelSize: 12
                    color: design.mut
                }
            }

            // Unread notifications, beside the time like Windows 11 (a crossed
            // out bell while Do not disturb is on).
            Rectangle {
                id: badge
                visible: notifs.quiet || notifs.unseen > 0
                anchors.left: clockText.right
                anchors.leftMargin: Math.round(8 * root.k)
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: notifs.quiet ? 18 : Math.max(18, badgeText.implicitWidth + 10)
                radius: 9
                color: notifs.quiet ? "transparent" : "#e0393e"    // red, like the taskbar's badges
                Text {
                    id: badgeText
                    visible: !notifs.quiet
                    anchors.centerIn: parent
                    text: notifs.unseen > 99 ? "99+" : String(notifs.unseen)
                    font.family: design.font
                    font.pixelSize: 11
                    font.bold: true
                    color: "white"
                }
                Glyph {
                    visible: notifs.quiet
                    anchors.centerIn: parent
                    name: "notifications_off"; fallback: "notifications-disabled"
                    size: 16
                    color: design.fg
                    fontAvailable: design.hasIconFont
                }
            }

            MouseArea {
                id: area
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // middle-click: Do not disturb on or off
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) notifs.toggleDnd();
                    else root.expanded = !root.expanded;
                }
            }
        }
    }

    fullRepresentation: Item {
        id: cal
        FloatingPopup {}
        Layout.preferredWidth: 360
        Layout.minimumWidth: 360
        Layout.maximumWidth: 360
        Layout.preferredHeight: notesPanel.implicitHeight + 1 + col.implicitHeight + 20
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        // The calendar is one long list of weeks rather than a page per month.
        // Days are counted as whole days since 1 January 1970 ("day numbers"),
        // worked out in UTC so clock changes never shift a day. Row "middle"
        // of the list is the week the calendar was opened in; each row works
        // out its own dates from its position, so nothing big is ever built.
        readonly property int middle: 5200          // about 100 years each way
        readonly property int rowHeight: 42         // one week
        readonly property int rowsShown: 6
        function dayNumber(d) {
            return Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000);
        }
        // The first day of the week (by the locale) on or before day number n.
        // 1 January 1970 was a Thursday (4; Sunday is 0, as in Qt.locale()).
        function weekStart(n) {
            const weekday = (n + 4) % 7;
            return n - (weekday - Qt.locale().firstDayOfWeek + 7) % 7;
        }
        // A month as one number (year * 12 + month), so months compare easily.
        function monthOf(n) {
            const d = new Date(n * 86400000);
            return d.getUTCFullYear() * 12 + d.getUTCMonth();
        }
        readonly property int firstWeek: weekStart(dayNumber(new Date()))   // fixed: row "middle"
        // today follows root.now, so it moves on at midnight by itself
        readonly property int todayNumber: dayNumber(root.now)
        readonly property int todayRow: middle + Math.floor((todayNumber - firstWeek) / 7)
        function rowOf(n) {
            return middle + Math.floor((n - firstWeek) / 7);
        }

        // The month in the header: the one in the middle of the third row
        // (just above the center of the list), so it changes as you scroll.
        function monthAtTop(top) {
            return monthOf(firstWeek + (top + 2 - middle) * 7 + 3);
        }
        readonly property real topRowExact: (weeks.contentY - weeks.originY) / rowHeight
        readonly property int shownMonth: monthOf(firstWeek + (Math.floor(topRowExact + rowsShown * 0.42) - middle) * 7 + 3)
        readonly property int lastTop: 2 * middle + 1 - rowsShown

        // Scroll so that row "top" is at the top: animated, or at once.
        property int target: -1     // where an animated scroll is going (-1: none)
        function scrollTo(top, animated) {
            top = Math.max(0, Math.min(lastTop, top));
            weeks.cancelFlick();
            slide.stop();
            if (animated) {
                target = top;
                slide.to = weeks.originY + top * rowHeight;
                slide.start();
            } else {
                target = -1;
                weeks.positionViewAtIndex(top, ListView.Beginning);
            }
        }
        function currentTop() {
            return target >= 0 ? target : Math.round(topRowExact);
        }
        // Previous/next: one month on from the month shown (or the one already
        // on its way), with the week of its 1st at the top.
        function shift(d) {
            const m = (target >= 0 ? monthAtTop(target) : shownMonth) + d;
            const first = dayNumber(new Date(Math.floor(m / 12), m % 12, 1));
            scrollTo(rowOf(first), true);
        }
        // On opening (and "Go to today"): the whole current month, starting
        // with the week of its 1st, like a month page. A month spans at most
        // six weeks, so today is always in view.
        function todayTop() {
            const now = root.now;
            return rowOf(dayNumber(new Date(now.getFullYear(), now.getMonth(), 1)));
        }
        // On first opening the list has no height yet and can't be scrolled:
        // then it is done as soon as the list gets its height.
        property bool resetPending: false
        function reset() {
            resetPending = weeks.height <= 0;
            scrollTo(todayTop(), false);
        }
        onVisibleChanged: if (visible)
            reset()
        // popups don't always toggle "visible": also reset each time it opens
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded)
                    cal.reset();
            }
        }

        NumberAnimation {
            id: slide
            target: weeks
            property: "contentY"
            duration: 250
            easing.type: Easing.OutCubic
            onFinished: {
                // land exactly on the row, whatever the list did meanwhile
                if (cal.target >= 0)
                    weeks.positionViewAtIndex(cal.target, ListView.Beginning);
                cal.target = -1;
            }
        }

        // a small square icon button, framed only while hovered
        component NavButton: Rectangle {
            id: nb
            property string glyph
            property string fallback
            property string tip
            signal clicked()
            implicitWidth: 32
            implicitHeight: 32
            radius: 6
            color: nbArea.containsMouse ? design.tintHover : "transparent"
            Glyph {
                anchors.centerIn: parent
                name: nb.glyph; fallback: nb.fallback
                size: 20; wght: 300
                color: design.text1
                fontAvailable: design.hasIconFont
            }
            MouseArea {
                id: nbArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: nb.clicked()
            }
            QQC2.ToolTip.visible: nbArea.containsMouse && nb.tip !== ""
            QQC2.ToolTip.text: nb.tip
            QQC2.ToolTip.delay: 500
        }

        // the notifications, above the calendar
        NotificationPanel {
            id: notesPanel
            notes: notifs
            pal: design
            width: parent.width
        }
        Rectangle {
            id: notesDivider
            anchors.top: notesPanel.bottom
            width: parent.width
            height: 1
            color: design.divider
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: notesDivider.bottom
            spacing: 0

            // Today, like "Sunday, November 15" (day and month in the order of
            // the panel's date format; no year)
            Text {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 16
                Layout.bottomMargin: 14
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Qt.formatDate(root.now, "dddd") + ", "
                    + Qt.formatDate(root.now, root.longDateFormat.replace(/,?\s*yyyy/, "").trim())
                font.family: design.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: design.text1
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: design.divider }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 14
                Layout.topMargin: 12
                Layout.bottomMargin: 6
                Item {
                    Layout.fillWidth: true
                    implicitHeight: monthName.implicitHeight
                    Text {
                        id: monthName
                        text: Qt.locale().standaloneMonthName(cal.shownMonth % 12) + " " + Math.floor(cal.shownMonth / 12)
                        font.family: design.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: design.text1
                        // Click the month to go back to today.
                        MouseArea {
                            id: monthArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.scrollTo(cal.todayTop(), true)
                        }
                        QQC2.ToolTip.visible: monthArea.containsMouse
                        QQC2.ToolTip.text: "Go to today"
                        QQC2.ToolTip.delay: 500
                    }
                }
                // up and down, as the weeks scroll up and down
                NavButton {
                    glyph: "keyboard_arrow_up"; fallback: "go-up-symbolic"; tip: "Previous month"
                    onClicked: cal.shift(-1)
                }
                NavButton {
                    glyph: "keyboard_arrow_down"; fallback: "go-down-symbolic"; tip: "Next month"
                    onClicked: cal.shift(1)
                }
            }

            QQC2.DayOfWeekRow {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                locale: Qt.locale()
                // no style gaps: each name must sit over its column of days
                spacing: 0
                leftPadding: 0
                rightPadding: 0
                delegate: Text {
                    required property string shortName
                    // "Su Mo Tu" in English, like Windows; other languages keep
                    // their own short names
                    text: Qt.locale().name.startsWith("en") ? shortName.substring(0, 2) : shortName
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    height: 30
                    font.family: design.font
                    font.pixelSize: 12
                    color: design.text2
                }
            }

            ListView {
                id: weeks
                objectName: "calendarWeeks"
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.preferredHeight: cal.rowsShown * cal.rowHeight
                clip: true
                model: cal.lastTop + cal.rowsShown
                boundsBehavior: Flickable.StopAtBounds
                snapMode: ListView.SnapToItem
                cacheBuffer: cal.rowHeight * 2
                // a drag or flick hands control back to the list
                onMovementStarted: {
                    slide.stop();
                    cal.target = -1;
                }
                Component.onCompleted: cal.reset()
                onHeightChanged: if (cal.resetPending && height > 0)
                    cal.reset()

                delegate: Row {
                    id: week
                    required property int index
                    readonly property int start: cal.firstWeek + (index - cal.middle) * 7
                    width: weeks.width
                    height: cal.rowHeight
                    Repeater {
                        model: 7
                        delegate: Item {
                            id: day
                            required property int index
                            readonly property int number: week.start + index
                            readonly property var date: new Date(number * 86400000)
                            readonly property int day: date.getUTCDate()
                            readonly property int monthKey: date.getUTCFullYear() * 12 + date.getUTCMonth()
                            // from root.now (through cal.todayNumber), so it
                            // moves on to the new day after midnight
                            readonly property bool today: number === cal.todayNumber
                            readonly property bool inMonth: monthKey === cal.shownMonth
                            width: weeks.width / 7
                            height: cal.rowHeight
                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: 18
                                color: day.today ? design.blue : dayArea.containsMouse ? design.tintHover : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                text: day.day
                                font.family: design.font
                                font.pixelSize: 13
                                font.weight: day.today ? Font.DemiBold : Font.Normal
                                color: day.today ? design.blueText : day.inMonth ? design.text1 : design.text3
                            }
                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }

                // The mouse wheel moves one week per notch (smoothly); a
                // touchpad scrolls freely and settles on a whole week after.
                property real wheelRest: 0
                Timer {
                    id: settle
                    interval: 160
                    onTriggered: cal.scrollTo(Math.round(cal.topRowExact), true)
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (wheel.pixelDelta.y !== 0) {
                            slide.stop();
                            cal.target = -1;
                            const top = weeks.originY, bottom = weeks.originY + cal.lastTop * cal.rowHeight;
                            weeks.contentY = Math.max(top, Math.min(bottom, weeks.contentY - wheel.pixelDelta.y));
                            settle.restart();
                        } else {
                            weeks.wheelRest += wheel.angleDelta.y;
                            const rows = Math.trunc(weeks.wheelRest / 120);
                            if (rows !== 0) {
                                weeks.wheelRest -= rows * 120;
                                cal.scrollTo(cal.currentTop() - rows, true);
                            }
                        }
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
}
