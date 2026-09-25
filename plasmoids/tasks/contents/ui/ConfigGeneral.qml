// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Taskbar settings: where the icons sit, and how big they are.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page
    // Tells Plasma's settings dialog that something changed, so Apply lights up.
    signal configurationChanged()

    property string cfg_alignment
    property int cfg_iconSize
    property bool cfg_expand
    property bool cfg_showAllDesktops
    property var cfg_launchers   // not shown here, but Plasma passes every setting in

    Kirigami.FormLayout {
        QQC2.ButtonGroup { id: alignGroup }

        QQC2.RadioButton {
            Kirigami.FormData.label: "Icon alignment:"
            text: "Center (on the screen)"
            QQC2.ButtonGroup.group: alignGroup
            checked: cfg_alignment !== "left"
            onToggled: if (checked) { cfg_alignment = "center"; page.configurationChanged(); }
        }
        QQC2.RadioButton {
            text: "Left (next to the start button)"
            QQC2.ButtonGroup.group: alignGroup
            checked: cfg_alignment === "left"
            onToggled: if (checked) { cfg_alignment = "left"; page.configurationChanged(); }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Desktops:"
            text: "Show apps from all desktops"
            checked: cfg_showAllDesktops
            onToggled: { cfg_showAllDesktops = checked; page.configurationChanged(); }
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: "Icon size:"
            spacing: Kirigami.Units.largeSpacing
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 18
                to: 36
                stepSize: 2
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_iconSize
                onMoved: { cfg_iconSize = value; page.configurationChanged(); }
            }
            QQC2.Label { text: cfg_iconSize + " px" }
        }
        QQC2.Button {
            text: "Reset to default (28 px)"
            icon.name: "edit-undo"
            flat: true
            onClicked: { cfg_iconSize = 28; page.configurationChanged(); }
        }
    }
}
