// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// A Material Symbols Rounded icon, drawn from the font by name.
// Falls back to a Plasma icon if the font is missing.
// A few icons of Tidewater's own are drawn here instead (set `svg` to one
// of the names in `drawings`); they take the same color and size as the font
// glyphs, and don't need the font at all.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: g
    property string name
    property string fallback
    property real size: 20
    property color color: "black"
    property bool filled: false
    // stroke weight of the font's outline (400 is Material's default; the
    // redesigned popups use 300, closer to Windows 11's thin icons)
    property int wght: 400
    property bool fontAvailable: true
    // Name of one of the drawings below. When set, it is shown instead of the
    // font glyph (and instead of the fallback).
    property string svg
    implicitWidth: size
    implicitHeight: size

    // The drawings, on Material's 24 unit grid, stroked like the font's outline
    // icons. The color and stroke width are filled in when drawn (see below);
    // WEIGHT_THIN marks a detail drawn at three quarters of the stroke.
    readonly property var drawings: ({
        // A monitor with an Ethernet plug on its lead (the user's design,
        // redrawn so its gaps stay open at 20 px).
        "ethernet": '<path d="M12.25 4H4.75A2 2 0 0 0 2.75 6V14A2 2 0 0 0 4.75 16H15.25"/>'
            + '<path d="M8.25 16V19.5M12.25 16V19.5M6.25 19.5H14.25"/>'
            + '<rect x="15.25" y="3" width="6" height="7" rx="1.75"/>'
            + '<path d="M17.5 5.75H19" stroke-width="WEIGHT_THIN"/>'
            + '<path d="M18.25 10V20.25"/>',
        // Do not disturb: a bell with "zZ" (the user's own design, drawn on
        // a 20 unit grid and filled, so it is scaled up to 24 and drawn in
        // the ink color instead of stroked).
        // Search: a magnifier with its handle to the lower left, like the
        // Windows one (the user's own design, on a 240 unit grid).
        "search": '<g transform="scale(0.1) translate(-44 -53.5)" stroke="INK" fill="none" stroke-linecap="round">'
            + '<circle cx="177.4" cy="154.6" r="81.4" stroke-width="22.7"/>'
            + '<path d="M119.3 220.8L71.8 269.5" stroke-width="28.5"/></g>',
        // The plain bell to go with it: the same shape, line and grid, without
        // the "zZ" (an outline; filled when there are new notifications).
        "bell": '<g transform="scale(1.2)" stroke="INK" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path fill="none" d="M9.75 16.08H2.75Q1.55 16.08 2.25 15.05L3.8 12.95V7.2C3.8 3.9 6.45 1.75 9.75 1.75C13.05 1.75 15.7 3.9 15.7 7.2V12.95L17.25 15.05Q17.95 16.08 16.75 16.08Z"/><path fill="none" d="M7.3 16.95C7.85 18.35 8.7 18.95 9.75 18.95C10.8 18.95 11.65 18.35 12.2 16.95"/></g>',
        "bell_filled": '<g transform="scale(1.2)" stroke="INK" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path fill="INK" d="M9.75 16.08H2.75Q1.55 16.08 2.25 15.05L3.8 12.95V7.2C3.8 3.9 6.45 1.75 9.75 1.75C13.05 1.75 15.7 3.9 15.7 7.2V12.95L17.25 15.05Q17.95 16.08 16.75 16.08Z"/><path fill="none" d="M7.3 16.95C7.85 18.35 8.7 18.95 9.75 18.95C10.8 18.95 11.65 18.35 12.2 16.95"/></g>',
        "snooze": '<g transform="scale(1.2)" fill="INK" stroke="none" fill-rule="evenodd"><path d="M10.14 19.37C10.62 19.33 10.99 19.20 11.62 18.82C12.12 18.52 12.27 18.36 12.66 17.66C13.21 16.71 12.94 16.79 15.35 16.78C17.44 16.76 17.33 16.77 17.68 16.54C18.55 15.96 18.60 15.20 17.83 14.18C17.70 14.01 17.51 13.75 17.42 13.62C17.33 13.49 17.12 13.21 16.97 13.00C16.37 12.20 16.37 12.22 16.35 10.66C16.34 9.96 16.32 9.40 16.31 9.35C16.20 8.98 15.96 8.80 15.61 8.83C15.24 8.86 15.03 9.10 14.97 9.58C14.93 9.98 14.95 12.42 15.01 12.61C15.09 12.92 15.42 13.46 15.73 13.85C16.71 15.04 16.75 15.32 15.94 15.38C15.56 15.40 3.94 15.40 3.56 15.38C3.14 15.35 3.00 15.26 3.00 15.04C3.00 14.88 3.07 14.78 3.88 13.69C4.55 12.80 4.48 13.20 4.50 9.86C4.51 7.12 4.51 7.11 4.57 6.93C4.60 6.82 4.68 6.52 4.75 6.25C4.93 5.55 4.97 5.46 5.37 4.80C6.03 3.68 6.92 2.96 8.06 2.59C8.21 2.54 8.50 2.45 8.69 2.39C9.36 2.18 9.81 2.17 10.55 2.36C11.57 2.62 11.88 2.62 12.16 2.34C12.51 2.00 12.38 1.45 11.87 1.20C11.04 0.78 9.17 0.69 8.21 1.02C8.03 1.08 7.72 1.18 7.51 1.25C7.01 1.41 6.92 1.45 6.32 1.81C5.38 2.35 4.39 3.37 3.87 4.33C3.79 4.46 3.32 5.80 3.21 6.19C3.13 6.49 3.12 6.78 3.10 9.40C3.08 12.59 3.16 12.18 2.41 13.16C1.37 14.54 1.16 14.92 1.17 15.44C1.17 15.99 1.55 16.49 2.13 16.70C2.31 16.76 2.31 16.76 4.14 16.78C6.50 16.80 6.35 16.75 6.75 17.52C7.12 18.23 7.54 18.66 8.28 19.08C8.73 19.34 9.37 19.44 10.14 19.37ZM9.51 17.91C8.52 17.64 8.01 17.02 8.62 16.83C8.81 16.77 10.69 16.77 10.88 16.82C11.35 16.96 11.24 17.31 10.61 17.69C10.18 17.94 9.87 18.01 9.51 17.91ZM11.96 11.38C12.33 11.23 12.48 10.83 12.29 10.45C12.16 10.19 11.95 10.11 11.39 10.07C10.68 10.04 10.57 10.01 10.49 9.85C10.37 9.63 10.47 9.47 11.47 8.29C12.22 7.41 12.28 7.33 12.34 7.11C12.48 6.61 12.24 6.26 11.71 6.17C11.37 6.12 8.44 6.15 8.29 6.21C7.73 6.42 7.61 6.95 8.04 7.32C8.22 7.48 8.40 7.52 8.95 7.55C9.97 7.59 10.00 7.80 9.16 8.75C8.96 8.98 8.71 9.28 8.61 9.43C8.50 9.57 8.34 9.78 8.24 9.90C7.59 10.68 7.63 11.21 8.36 11.41C8.61 11.48 11.77 11.45 11.96 11.38ZM18.42 7.49C19.17 7.27 19.18 6.39 18.45 6.20C18.38 6.18 17.96 6.16 17.41 6.15C16.42 6.13 16.36 6.12 16.22 6.00C16.08 5.86 16.15 5.63 16.43 5.29C16.82 4.81 17.22 4.27 17.48 3.89C17.63 3.67 17.97 3.20 18.24 2.86C18.77 2.19 18.88 2.02 18.95 1.82C19.09 1.42 18.89 1.03 18.48 0.90C18.28 0.83 14.84 0.79 14.41 0.85C13.84 0.93 13.55 1.39 13.78 1.84C13.95 2.17 14.09 2.20 15.26 2.22C16.33 2.25 16.42 2.26 16.50 2.45C16.57 2.62 16.49 2.78 16.12 3.23C15.80 3.61 15.70 3.75 15.41 4.19C15.27 4.39 15.02 4.73 14.86 4.93C14.70 5.12 14.47 5.43 14.34 5.60C14.22 5.77 14.06 5.98 14.00 6.07C13.48 6.75 13.68 7.43 14.41 7.52C14.75 7.57 18.27 7.54 18.42 7.49Z"/></g>'
    })

    // The font's stroke gets thicker up to optical size 24 and thinner above
    // it. These match its outline weight (400) on the 24 unit grid, measured
    // from the font itself.
    function weight(px) {
        const o = Math.max(20, Math.min(48, px));
        return o <= 24 ? 1.8 + (o - 20) * 0.05 : 2.0 - (o - 24) * 0.023;
    }

    // Data URL for a drawing. The color goes in as plain #rrggbb (SVG doesn't
    // read Qt's #aarrggbb); any transparency is applied through `opacity`.
    function drawingUrl(key, c, px) {
        const body = drawings[key];
        if (!body) return "";
        const hex = n => ("0" + Math.round(n * 255).toString(16)).slice(-2);
        const ink = "#" + hex(c.r) + hex(c.g) + hex(c.b);
        const w = weight(px);
        const markup = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
            + ink + '" stroke-width="' + w.toFixed(3)
            + '" stroke-linecap="round" stroke-linejoin="round">'
            + body.replace(/WEIGHT_THIN/g, (w * 0.75).toFixed(3)).replace(/INK/g, ink) + '</svg>';
        return "data:image/svg+xml;utf8," + encodeURIComponent(markup);
    }

    readonly property bool drawn: svg.length > 0 && drawings[svg] !== undefined

    Text {
        anchors.centerIn: parent
        visible: g.fontAvailable && !g.drawn
        text: g.name
        color: g.color
        font.family: "Material Symbols Rounded"
        font.pixelSize: g.size
        font.variableAxes: ({ "FILL": g.filled ? 1 : 0, "wght": g.wght, "opsz": Math.max(20, Math.min(48, g.size)) })
        renderType: Text.QtRendering
    }
    Kirigami.Icon {
        anchors.fill: parent
        visible: !g.drawn && !g.fontAvailable && g.fallback.length > 0
        source: g.fallback
        color: g.color
        isMask: true
    }
    Image {
        anchors.centerIn: parent
        width: g.size
        height: g.size
        visible: g.drawn
        // Drawn at the screen's real pixel size, so it stays sharp with HiDPI
        // and fractional scaling. (Qt only does this by itself for files that
        // end in .svg, not for a data URL like this one.)
        readonly property real px: Math.ceil(g.size * Math.max(1, Screen.devicePixelRatio))
        sourceSize: Qt.size(px, px)
        source: g.drawn ? g.drawingUrl(g.svg, g.color, g.size) : ""
        opacity: g.color.a
        smooth: true
        cache: true
    }
}
