// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The design's colour roles, worked out by the colour engine (Scheme.js).
// Light or dark follows Plasma; the seed is the design's blue, so the colours
// match the screenshots exactly in both modes.
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

    readonly property var families: Qt.fontFamilies()
    readonly property string font: families.indexOf("Rubik") >= 0 ? "Rubik" : Kirigami.Theme.defaultFont.family
    readonly property bool hasIconFont: families.indexOf("Material Symbols Rounded") >= 0

    function alpha(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a); }

    // Everything is sized from the bar thickness, designed at 64px.
    readonly property int thickness: 52
    readonly property real unit: thickness / 64
}
