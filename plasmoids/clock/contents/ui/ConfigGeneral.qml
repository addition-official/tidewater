// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Clock settings: seconds, 24-hour time, the date line and its format.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page
    // Tells Plasma's settings dialog that something changed, so Apply lights up.
    signal configurationChanged()

    property bool cfg_showSeconds
    property bool cfg_showDate
    property string cfg_hourMode
    property string cfg_dateFormat

    // Ready-made orders, shown using today's date; "Custom" keeps whatever is typed.
    readonly property var presets: [
        { fmt: "ddd d MMM" },
        { fmt: "ddd, MMM d" },
        { fmt: "d MMM" },
        { fmt: "MMM d" },
        { fmt: "dd/MM/yyyy" },
        { fmt: "MM/dd/yyyy" },
        { fmt: "yyyy-MM-dd" },
        { fmt: "dddd d MMMM" }
    ]
    function presetIndex(fmt) {
        for (let i = 0; i < presets.length; ++i)
            if (presets[i].fmt === fmt) return i;
        return presets.length;   // Custom
    }
    function setFormat(fmt) {
        cfg_dateFormat = fmt;
        page.configurationChanged();
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: "Time:"
            text: "Show seconds"
            checked: cfg_showSeconds
            onToggled: { cfg_showSeconds = checked; page.configurationChanged(); }
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Hours:"
            readonly property var modes: ["system", "24h", "12h"]
            model: ["Same as system", "24-hour (17:43)", "12-hour (5:43 PM)"]
            currentIndex: Math.max(0, modes.indexOf(cfg_hourMode))
            onActivated: index => { cfg_hourMode = modes[index]; page.configurationChanged(); }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Date:"
            text: "Show the date under the time"
            checked: cfg_showDate
            onToggled: { cfg_showDate = checked; page.configurationChanged(); }
        }

        QQC2.ComboBox {
            id: presetBox
            Kirigami.FormData.label: "Date format:"
            enabled: cfg_showDate
            model: page.presets.map(p => Qt.formatDate(new Date(), p.fmt)).concat(["Custom"])
            currentIndex: page.presetIndex(cfg_dateFormat)
            onActivated: index => {
                if (index < page.presets.length) page.setFormat(page.presets[index].fmt);
                else customField.forceActiveFocus();
            }
        }
        QQC2.TextField {
            id: customField
            Kirigami.FormData.label: "Pattern:"
            enabled: cfg_showDate
            text: cfg_dateFormat
            placeholderText: "ddd d MMM"
            onTextEdited: page.setFormat(text)
        }
        QQC2.Label {
            Kirigami.FormData.label: "Preview:"
            text: Qt.formatDate(new Date(), cfg_dateFormat || "ddd d MMM")
            font.weight: Font.Medium
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Put the parts in any order: d or dd = day, ddd or dddd = weekday, "
                + "M, MM, MMM or MMMM = month, yy or yyyy = year. "
                + "Other characters (spaces, commas, dots, slashes) show as typed; "
                + "wrap letters in 'single quotes' to show them literally."
        }
    }
}
