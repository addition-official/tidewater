// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The design's color roles, worked out by the color engine (Scheme.js).
// Light or dark follows Plasma; the seed is the design's blue, which gives
// the same colors on every machine in both modes.
import QtQuick
import org.kde.kirigami as Kirigami
import "Scheme.js" as Scheme

Item {
    visible: false
    readonly property bool dark: Scheme.isDark(Kirigami.Theme.backgroundColor.toString())
    readonly property var r: Scheme.scheme("#466fbd", dark)

    readonly property color acc: r.primary
    readonly property color accFg: r.onPrimary
    readonly property color accC: r.primaryContainer
    readonly property color accCFg: r.onPrimaryContainer
    readonly property color surface: r.surface
    readonly property color s1: r.surfaceContainerLow
    readonly property color s2: r.surfaceContainerHigh
    readonly property color s3: dark ? r.surfaceContainerHighest : r.surfaceContainerLowest
    readonly property color fg: r.onSurface
    readonly property color mut: r.onSurfaceVariant
    readonly property color out: r.outlineVariant
    readonly property color danger: r.error

    // ---- the popups (start menu, quick settings, calendar, notifications) ----
    // Neutral layers drawn over Plasma's popup background, three text levels,
    // and one clear accent used only for what is on or selected. (Property
    // names can't start with "on": QML would take them for signal handlers.)
    readonly property color text1: dark ? "#ececf1" : "#1b1b1f"
    readonly property color text2: dark ? "#a9acb5" : "#5b5e66"
    readonly property color text3: dark ? "#757882" : "#8a8d95"
    readonly property color tint: dark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.035)
    readonly property color tintHover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color stroke: dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color blue: dark ? "#5aa7ff" : "#0a62c9"
    readonly property color blueText: dark ? "#04213f" : "#ffffff"

    readonly property var families: Qt.fontFamilies()
    readonly property string font: families.indexOf("Rubik") >= 0 ? "Rubik" : Kirigami.Theme.defaultFont.family
    readonly property bool hasIconFont: families.indexOf("Material Symbols Rounded") >= 0

    function alpha(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a); }

    // Everything is sized from the bar thickness, designed at 64px.
    readonly property int thickness: 52
    readonly property real unit: thickness / 64
}
