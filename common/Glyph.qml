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
            + '<path d="M18.25 10V20.25"/>'
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
            + body.replace(/WEIGHT_THIN/g, (w * 0.75).toFixed(3)) + '</svg>';
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
        font.variableAxes: ({ "FILL": g.filled ? 1 : 0, "opsz": Math.max(20, Math.min(48, g.size)) })
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
