// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Tidewater settings: one page for the whole panel. It is the start widget's
// Configure page; every other Tidewater widget opens it from its right-click
// menu ("Tidewater settings..."). Plasma saves what is set here into the start
// widget's configuration on Apply, and the start widget shares it with the
// rest (see main.qml and shared/Settings.qml).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import "common"
// Only for its defaults and icon helpers: this dialog has its own QML engine,
// so this is a separate copy, not the one the panel widgets share.
import "../../../../../tidewater/qml"

KCM.SimpleKCM {
    id: page
    // Tells Plasma's settings dialog that something changed, so Apply lights up.
    signal configurationChanged()

    // Every setting of the start widget. Plasma fills these in when the page
    // opens and saves them on Apply.
    property string cfg_startIcon
    property string cfg_searchStyle
    property bool cfg_showOverview
    property string cfg_workspaces
    property bool cfg_showDividers
    property bool cfg_showPower
    property string cfg_alignment
    property int cfg_iconSize
    property bool cfg_expand
    property bool cfg_showAllDesktops
    property bool cfg_showSeconds
    property bool cfg_showDate
    property string cfg_hourMode
    property string cfg_dateFormat
    property string cfg_settingsRev
    property var cfg_pinned   // not shown here, but Plasma passes every setting in
    // Plasma also passes each setting's default value; declared so it has
    // somewhere to go (otherwise it logs a warning for each one).
    property string cfg_startIconDefault
    property string cfg_searchStyleDefault
    property bool cfg_showOverviewDefault
    property string cfg_workspacesDefault
    property bool cfg_showDividersDefault
    property bool cfg_showPowerDefault
    property string cfg_alignmentDefault
    property int cfg_iconSizeDefault
    property bool cfg_expandDefault
    property bool cfg_showAllDesktopsDefault
    property bool cfg_showSecondsDefault
    property bool cfg_showDateDefault
    property string cfg_hourModeDefault
    property string cfg_dateFormatDefault
    property string cfg_settingsRevDefault
    property var cfg_pinnedDefault

    // Something was changed on this page.
    property bool edited: false
    // Call after every change: Apply lights up, and the settings get a new
    // time stamp, so they win over the older ones of any other start widget.
    function touch() {
        edited = true;
        cfg_settingsRev = root_nextRev();
        page.configurationChanged();
    }
    // Plasma calls this just before it saves: stamp the moment of Apply.
    // (OK or Apply with nothing changed keeps the old stamp, so it can't undo
    // newer settings saved meanwhile from another monitor's start button.)
    // A save must always count as newer than the settings this page started
    // from, even if the computer's clock is behind the time they were saved
    // (e.g. after a dual-boot clock mix-up); otherwise it would be undone.
    function root_nextRev() {
        return String(Math.max(Date.now(), (Number(cfg_settingsRev) || 0) + 1));
    }

    function saveConfig() {
        // Plasma writes every cfg_ value back on Apply, pins included: take the
        // pins as they are right now, so pinning from the start menu while this
        // window is open isn't undone.
        if (typeof plasmoid !== "undefined" && plasmoid && plasmoid.configuration)
            cfg_pinned = plasmoid.configuration.pinned;
        if (edited)
            cfg_settingsRev = root_nextRev();
        edited = false;
    }

    // ---- start icon ------------------------------------------------------------
    function setIcon(v) {
        cfg_startIcon = v.trim();
        touch();
    }
    // file:///home/me/a%20b.svg -> /home/me/a b.svg (easier to read and edit)
    function localPath(url) {
        const s = String(url);
        return s.startsWith("file://") ? decodeURIComponent(s.substring(7)) : s;
    }

    // ---- clock date format -----------------------------------------------------
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
            if (presets[i].fmt === fmt)
                return i;
        return presets.length;   // Custom
    }
    function setFormat(fmt) {
        cfg_dateFormat = fmt;
        touch();
    }

    Palette { id: design }

    // KDE's own icon picker (icons from your theme; it can also browse files)
    KIconThemes.IconDialog {
        id: iconDialog
        onAccepted: if (iconName) page.setIcon(String(iconName))
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: "Choose a picture for the start button"
        nameFilters: ["Images (*.svg *.svgz *.png *.jpg *.jpeg *.webp)"]
        onAccepted: page.setIcon(page.localPath(selectedFile))
    }

    Kirigami.FormLayout {
        // ==== Start button
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Start button"
        }
        // The start button as the panel draws it (just a picture, it can't be
        // clicked), and a "Change" button next to it with the options.
        RowLayout {
            Kirigami.FormData.label: "Icon:"
            spacing: Kirigami.Units.largeSpacing

            BarButton {
                id: iconPreview
                objectName: "iconPreview"
                pal: design
                filled: true
                accentGlyph: true
                buttons: Qt.NoButton
                size: Math.max(24, Math.round(46 * design.unit))
                glyph: cfg_startIcon ? "" : "blur_on"
                fallback: "start-here-kde-symbolic"
                image: Settings.iconSource(cfg_startIcon)
                imageTinted: !Settings.isFile(cfg_startIcon)
            }

            QQC2.Button {
                id: changeButton
                objectName: "changeIconButton"
                text: "Change"
                icon.name: "edit-entry"
                Accessible.role: Accessible.ButtonMenu
                onClicked: iconMenu.opened ? iconMenu.close() : iconMenu.open()

                QQC2.Menu {
                    id: iconMenu
                    objectName: "iconMenu"
                    y: parent.height        // open below the button
                    QQC2.MenuItem {
                        text: "Choose an icon..."
                        icon.name: "preferences-desktop-icons"
                        onClicked: iconDialog.open()
                    }
                    QQC2.MenuItem {
                        text: "Use a picture file..."
                        icon.name: "document-open"
                        onClicked: fileDialog.open()
                    }
                    QQC2.MenuItem {
                        text: "Reset to default"
                        icon.name: "edit-undo"
                        enabled: cfg_startIcon !== ""
                        onClicked: page.setIcon("")
                    }
                }
            }
        }

        // ==== Search
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Search"
        }
        QQC2.ButtonGroup { id: searchGroup }
        QQC2.RadioButton {
            Kirigami.FormData.label: "Search button:"
            text: "Icon and \"Search\""
            QQC2.ButtonGroup.group: searchGroup
            checked: cfg_searchStyle !== "icon" && cfg_searchStyle !== "hidden"
            onToggled: if (checked) {
                cfg_searchStyle = "full";
                page.touch();
            }
        }
        QQC2.RadioButton {
            text: "Icon only"
            QQC2.ButtonGroup.group: searchGroup
            checked: cfg_searchStyle === "icon"
            onToggled: if (checked) {
                cfg_searchStyle = "icon";
                page.touch();
            }
        }
        QQC2.RadioButton {
            text: "Hidden"
            QQC2.ButtonGroup.group: searchGroup
            checked: cfg_searchStyle === "hidden"
            onToggled: if (checked) {
                cfg_searchStyle = "hidden";
                page.touch();
            }
        }

        // ==== Overview, desktops, dividers, power
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Panel"
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Overview:"
            text: "Show the overview button"
            checked: cfg_showOverview
            onToggled: {
                cfg_showOverview = checked;
                page.touch();
            }
        }
        QQC2.ButtonGroup { id: desktopsGroup }
        QQC2.RadioButton {
            Kirigami.FormData.label: "Desktops:"
            text: "Numbered pills"
            QQC2.ButtonGroup.group: desktopsGroup
            checked: cfg_workspaces !== "dots" && cfg_workspaces !== "hidden"
            onToggled: if (checked) {
                cfg_workspaces = "numbers";
                page.touch();
            }
        }
        QQC2.RadioButton {
            text: "Dots"
            QQC2.ButtonGroup.group: desktopsGroup
            checked: cfg_workspaces === "dots"
            onToggled: if (checked) {
                cfg_workspaces = "dots";
                page.touch();
            }
        }
        QQC2.RadioButton {
            text: "Hidden"
            QQC2.ButtonGroup.group: desktopsGroup
            checked: cfg_workspaces === "hidden"
            onToggled: if (checked) {
                cfg_workspaces = "hidden";
                page.touch();
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Dividers:"
            text: "Show the dividers"
            checked: cfg_showDividers
            onToggled: {
                cfg_showDividers = checked;
                page.touch();
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Power:"
            text: "Show the power button"
            checked: cfg_showPower
            onToggled: {
                cfg_showPower = checked;
                page.touch();
            }
        }

        // ==== Taskbar
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Taskbar"
        }
        QQC2.ButtonGroup { id: alignGroup }
        QQC2.RadioButton {
            Kirigami.FormData.label: "Icon alignment:"
            text: "Center (on the screen)"
            QQC2.ButtonGroup.group: alignGroup
            checked: cfg_alignment !== "left"
            onToggled: if (checked) {
                cfg_alignment = "center";
                page.touch();
            }
        }
        QQC2.RadioButton {
            text: "Left (next to the start button)"
            QQC2.ButtonGroup.group: alignGroup
            checked: cfg_alignment === "left"
            onToggled: if (checked) {
                cfg_alignment = "left";
                page.touch();
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Width:"
            text: "Fill the bar (needed to center the icons on the screen)"
            checked: cfg_expand
            onToggled: {
                cfg_expand = checked;
                page.touch();
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Desktops:"
            text: "Show apps from all desktops"
            checked: cfg_showAllDesktops
            onToggled: {
                cfg_showAllDesktops = checked;
                page.touch();
            }
        }
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
                onMoved: {
                    cfg_iconSize = value;
                    page.touch();
                }
            }
            QQC2.Label { text: cfg_iconSize + " px" }
        }
        QQC2.Button {
            text: "Reset to default (28 px)"
            icon.name: "edit-undo"
            flat: true
            onClicked: {
                cfg_iconSize = Settings.defaults.iconSize;
                page.touch();
            }
        }

        // ==== Clock
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Clock"
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Time:"
            text: "Show seconds"
            checked: cfg_showSeconds
            onToggled: {
                cfg_showSeconds = checked;
                page.touch();
            }
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Hours:"
            readonly property var modes: ["system", "24h", "12h"]
            model: ["Same as system", "24-hour (17:43)", "12-hour (5:43 PM)"]
            currentIndex: Math.max(0, modes.indexOf(cfg_hourMode))
            onActivated: index => {
                cfg_hourMode = modes[index];
                page.touch();
            }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Date:"
            text: "Show the date under the time"
            checked: cfg_showDate
            onToggled: {
                cfg_showDate = checked;
                page.touch();
            }
        }
        QQC2.ComboBox {
            id: presetBox
            Kirigami.FormData.label: "Date format:"
            enabled: cfg_showDate
            model: page.presets.map(p => Qt.formatDate(new Date(), p.fmt)).concat(["Custom"])
            currentIndex: page.presetIndex(cfg_dateFormat)
            onActivated: index => {
                if (index < page.presets.length)
                    page.setFormat(page.presets[index].fmt);
                else
                    customField.forceActiveFocus();
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
