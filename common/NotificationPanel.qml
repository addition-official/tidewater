// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The notification center in the manner of Windows 11: "Notifications" with
// Clear all and a Do not disturb button, then one card per notification
// (newest first): the app's icon, name and the time on top, then the title
// and the text. Hovering a card shows a close button where the time is.
// Shows a NotificationData (`notes`).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Column {
    id: panel
    required property var notes     // NotificationData.qml
    required property var pal       // Palette.qml
    property int maxListHeight: 340
    property bool expanded: false   // "Show N more" was clicked
    readonly property int collapsedCount: 4
    width: parent ? parent.width : 0

    // ---- header ----
    Item {
        width: parent.width
        height: 48
        Text {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            font.family: panel.pal.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: panel.pal.text1
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Rectangle {
                visible: panel.notes.count > 0
                width: clearText.implicitWidth + 20
                height: 30
                radius: 6
                color: clearArea.containsMouse ? panel.pal.tintHover : "transparent"
                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear all"
                    font.family: panel.pal.font
                    font.pixelSize: 12
                    color: panel.pal.text1
                }
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.notes.clearAll()
                }
            }
            Rectangle {
                width: 30
                height: 30
                radius: 6
                color: panel.notes.quiet ? panel.pal.blue : dndArea.containsMouse ? panel.pal.tintHover : "transparent"
                Glyph {
                    anchors.centerIn: parent
                    name: "notifications_off"; fallback: "notifications-disabled"
                    size: 18; wght: 300
                    filled: panel.notes.quiet
                    color: panel.notes.quiet ? panel.pal.blueText : panel.pal.text1
                    fontAvailable: panel.pal.hasIconFont
                }
                MouseArea {
                    id: dndArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.notes.toggleDnd()
                }
                QQC2.ToolTip.visible: dndArea.containsMouse
                QQC2.ToolTip.text: panel.notes.quiet ? "Turn off Do not disturb" : "Do not disturb"
                QQC2.ToolTip.delay: 500
            }
        }
    }

    // ---- the cards ----
    Flickable {
        visible: panel.notes.count > 0
        x: 12
        width: parent.width - 24
        height: Math.min(contentHeight, panel.maxListHeight)
        contentHeight: cards.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
        Column {
            id: cards
            width: parent.width
            spacing: 8
            Repeater {
                model: panel.expanded ? panel.notes.entries : panel.notes.entries.slice(0, panel.collapsedCount)
                Rectangle {
                    id: card
                    required property var modelData
                    width: cards.width
                    height: cardCol.implicitHeight + 26
                    radius: 8
                    color: cardArea.containsMouse || closeHover.hovered ? panel.pal.tintHover : panel.pal.tint
                    border.width: 1
                    border.color: panel.pal.stroke
                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: card.modelData.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (card.modelData.hasDefault) panel.notes.invoke(card.modelData.id)
                    }
                    Column {
                        id: cardCol
                        x: 14
                        y: 13
                        width: parent.width - 28
                        spacing: 8
                        // the app, and the time (or a close button while hovered)
                        Item {
                            width: parent.width
                            height: 18
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    source: card.modelData.icon || "preferences-desktop-notification"
                                    fallback: "preferences-desktop-notification"
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, cardCol.width - 120)
                                    elide: Text.ElideRight
                                    text: card.modelData.app
                                    textFormat: Text.PlainText   // app-supplied text: never render it as HTML
                                    font.family: panel.pal.font
                                    font.pixelSize: 12
                                    color: panel.pal.text2
                                }
                            }
                            Text {
                                visible: !closeBox.visible
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: panel.notes.ago(card.modelData.when)
                                font.family: panel.pal.font
                                font.pixelSize: 11
                                color: panel.pal.text3
                            }
                            Rectangle {
                                id: closeBox
                                visible: cardArea.containsMouse || closeHover.hovered
                                anchors.right: parent.right
                                anchors.rightMargin: -6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: 6
                                color: closeHover.hovered ? panel.pal.tintHover : "transparent"
                                HoverHandler { id: closeHover }
                                Glyph {
                                    anchors.centerIn: parent
                                    name: "close"; fallback: "window-close"
                                    size: 16; wght: 300
                                    color: panel.pal.text2
                                    fontAvailable: panel.pal.hasIconFont
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.notes.dismiss(card.modelData.id)
                                }
                                QQC2.ToolTip.visible: closeHover.hovered
                                QQC2.ToolTip.text: "Dismiss"
                                QQC2.ToolTip.delay: 500
                            }
                        }
                        Column {
                            width: parent.width
                            spacing: 3
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: card.modelData.summary
                                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                font.family: panel.pal.font
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: card.modelData.critical ? panel.pal.danger : panel.pal.text1
                            }
                            Text {
                                visible: text.length > 0
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                text: card.modelData.body
                                textFormat: Text.PlainText   // app/web-supplied text: never render it as HTML
                                font.family: panel.pal.font
                                font.pixelSize: 12
                                color: panel.pal.text2
                            }
                        }
                    }
                }
            }
            Text {
                visible: panel.notes.count > panel.collapsedCount
                leftPadding: 4
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: panel.expanded ? "Show less" : "Show " + (panel.notes.count - panel.collapsedCount) + " more"
                font.family: panel.pal.font
                font.pixelSize: 12
                color: moreArea.containsMouse ? Qt.lighter(panel.pal.blue, 1.15) : panel.pal.blue
                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.expanded = !panel.expanded
                }
            }
        }
    }

    // ---- nothing to show ----
    Text {
        visible: panel.notes.count === 0
        width: parent.width
        height: 44
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: panel.notes.quiet ? "Do not disturb is on" : "No new notifications"
        font.family: panel.pal.font
        font.pixelSize: 13
        color: panel.pal.text2
    }

    Item { width: 1; height: 12 }
}
