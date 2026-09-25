// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Clock: time over date ("20:35 / Tue 15 Sep"),
// a soft pill on hover, and a month calendar when clicked.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "common"

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Palette { id: design }

    property date now: new Date()
    // Tick right after each second (or, with seconds hidden, at least every 5 s
    // and right after each minute), so the display never lags or skips.
    function nextDelay() {
        const t = Date.now();
        return root.showSeconds ? 1000 - t % 1000 + 20
            : Math.min(5000, 60000 - t % 60000 + 20);
    }
    Timer {
        id: tick
        interval: root.nextDelay()
        running: true
        onTriggered: { root.now = new Date(); interval = root.nextDelay(); start(); }
    }
    readonly property bool showSeconds: Plasmoid.configuration.showSeconds
    onShowSecondsChanged: { now = new Date(); tick.interval = nextDelay(); tick.restart(); }

    // 12- or 24-hour: "system" follows Region & Language; "24h"/"12h" override it.
    // Seconds are this clock's own option.
    readonly property string hourMode: Plasmoid.configuration.hourMode || "system"
    readonly property string systemFormat: hourMode === "24h" ? "HH:mm"
        : hourMode === "12h" ? "h:mm AP"
        : Qt.locale().timeFormat(Locale.ShortFormat)
    readonly property string timeFormat: Plasmoid.configuration.showSeconds && root.systemFormat.indexOf("ss") < 0
        ? root.systemFormat.replace("mm", "mm:ss") : root.systemFormat

    toolTipMainText: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat))
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
            height: design.thickness - 8
            radius: Math.round(13 * root.k)
            color: area.containsMouse || root.expanded ? design.s2 : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Column {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    id: time
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.now, root.timeFormat)
                    font.features: { "tnum": 1 }   // equal-width digits: no wobble as seconds tick
                    font.family: design.font
                    font.pixelSize: Math.round(14 * Math.min(1, Math.max(0.9, design.unit)))
                    font.weight: Font.Medium
                    color: design.fg
                }
                Text {
                    id: date
                    visible: Plasmoid.configuration.showDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.now, Plasmoid.configuration.dateFormat || "ddd d MMM")
                    font.family: design.font
                    font.pixelSize: 12
                    color: design.mut
                }
            }

            MouseArea {
                acceptedButtons: Qt.LeftButton
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    fullRepresentation: Item {
        id: cal
        Layout.preferredWidth: 320
        Layout.minimumWidth: 320
        Layout.preferredHeight: col.implicitHeight + 32
        Layout.minimumHeight: Layout.preferredHeight

        property int month: root.now.getMonth()
        property int year: root.now.getFullYear()
        function shift(d) {
            let m = month + d, y = year;
            if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
            month = m; year = y;
        }
        function reset() { month = root.now.getMonth(); year = root.now.getFullYear(); }
        onVisibleChanged: if (visible) reset()
        // popups don't always toggle "visible": also reset each time it opens
        Connections {
            target: root
            function onExpandedChanged() { if (root.expanded) cal.reset(); }
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            ColumnLayout {
                spacing: 0
                Text {
                    text: Qt.formatDate(root.now, "dddd")
                    font.family: design.font; font.pixelSize: 13; color: design.mut
                }
                Text {
                    text: Qt.formatDate(root.now, "d MMMM yyyy")
                    font.family: design.font; font.pixelSize: 20; font.weight: Font.Medium; color: design.fg
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Qt.locale().standaloneMonthName(cal.month) + " " + cal.year
                    font.family: design.font; font.pixelSize: 14; font.weight: Font.Medium; color: design.fg
                }
                BarButton { pal: design; size: 30; glyph: "chevron_left"; fallback: "go-previous-symbolic"; onClicked: cal.shift(-1) }
                BarButton { pal: design; size: 30; glyph: "chevron_right"; fallback: "go-next-symbolic"; onClicked: cal.shift(1) }
            }

            QQC2.DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()
                delegate: Text {
                    required property string shortName
                    text: shortName
                    horizontalAlignment: Text.AlignHCenter
                    font.family: design.font; font.pixelSize: 11; color: design.mut
                }
            }

            QQC2.MonthGrid {
                Layout.fillWidth: true
                month: cal.month
                year: cal.year
                locale: Qt.locale()
                delegate: Item {
                    id: day
                    required property var model
                    implicitWidth: 36
                    implicitHeight: 32
                    readonly property bool today: model.today
                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 10
                        color: day.today ? design.acc : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: day.model.day
                        font.family: design.font; font.pixelSize: 13
                        font.weight: day.today ? Font.Medium : Font.Normal
                        color: day.today ? design.accFg : design.fg
                        opacity: day.model.month === cal.month ? 1 : 0.35
                    }
                }
            }
        }
    }
}
