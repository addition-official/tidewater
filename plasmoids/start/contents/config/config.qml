// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The settings page for all of Tidewater. It belongs to the start widget, which
// saves the settings for every Tidewater widget (see shared/Settings.qml).
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Tidewater"
        icon: "preferences-desktop"
        source: "ConfigGeneral.qml"
    }
}
