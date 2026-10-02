.pragma library
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Marius Gabriel Lupu (remapprShell, https://github.com/Wolffyx/remapprShell)
// SPDX-FileCopyrightText: 2026 addition-official
// Taken from remapprShell and modified for Tidewater by addition-official, 2026.
// Color engine: builds every color role from one seed color, light or dark.

// ---- color in, color out -------------------------------------------

// "#rgb", "#rrggbb", "#aarrggbb" (alpha ignored) or "r,g,b" (as kdeglobals
// writes them). Null for anything else.
function parse(value) {
    const s = String(value ?? "").trim().toLowerCase();
    let m = /^#([0-9a-f]{3})$/.exec(s);
    if (m)
        return { r: parseInt(m[1][0] + m[1][0], 16), g: parseInt(m[1][1] + m[1][1], 16), b: parseInt(m[1][2] + m[1][2], 16) };
    m = /^#(?:[0-9a-f]{2})?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/.exec(s);
    if (m)
        return { r: parseInt(m[1], 16), g: parseInt(m[2], 16), b: parseInt(m[3], 16) };
    m = /^(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})/.exec(s);
    if (m)
        return { r: Math.min(255, +m[1]), g: Math.min(255, +m[2]), b: Math.min(255, +m[3]) };
    return null;
}

function hex(rgb) {
    const h = v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0");
    return `#${h(rgb.r)}${h(rgb.g)}${h(rgb.b)}`;
}

// Any color this file accepts, as "#rrggbb"; the fallback when it is none.
function normalize(value, fallback) {
    const rgb = parse(value);
    return rgb ? hex(rgb) : fallback;
}

// ---- sRGB <-> CIELAB (D65) --------------------------------------------

function _toLinear(c) {
    const v = c / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function _fromLinear(v) {
    const c = v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
    return c * 255;
}

function _clampRgb(lin) {
    return { r: _fromLinear(Math.max(0, Math.min(1, lin.r))),
             g: _fromLinear(Math.max(0, Math.min(1, lin.g))),
             b: _fromLinear(Math.max(0, Math.min(1, lin.b))) };
}

var _eps = 216 / 24389
var _kappa = 24389 / 27

function _f(t) { return t > _eps ? Math.cbrt(t) : (_kappa * t + 16) / 116; }
function _finv(t) { const c = t * t * t; return c > _eps ? c : (116 * t - 16) / _kappa; }

function lab(value) {
    const rgb = parse(value) ?? { r: 0, g: 0, b: 0 };
    const r = _toLinear(rgb.r), g = _toLinear(rgb.g), b = _toLinear(rgb.b);
    const x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    const y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    const z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
    const fx = _f(x), fy = _f(y), fz = _f(z);
    return { l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
}

function lch(value) {
    const c = lab(value);
    const h = Math.atan2(c.b, c.a) * 180 / Math.PI;
    return { l: c.l, c: Math.hypot(c.a, c.b), h: (h + 360) % 360 };
}

// Linear sRGB for a CIELAB LCh color, possibly outside [0, 1].
function _lchToLinear(l, c, h) {
    const a = c * Math.cos(h * Math.PI / 180), b = c * Math.sin(h * Math.PI / 180);
    const fy = (l + 16) / 116, fx = fy + a / 500, fz = fy - b / 200;
    const x = _finv(fx) * 0.95047;
    const y = l > 8 ? Math.pow(fy, 3) : l / _kappa;
    const z = _finv(fz) * 1.08883;
    return { r: 3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
             g: -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
             b: 0.0556434 * x - 0.2040259 * y + 1.0572252 * z };
}

function _inGamut(lin) {
    const e = 1e-4;
    return lin.r >= -e && lin.r <= 1 + e && lin.g >= -e && lin.g <= 1 + e && lin.b >= -e && lin.b <= 1 + e;
}

// ---- tones -------------------------------------------------------------

// The color of `hue` and at most `chroma` whose L* is exactly `tone`.
// Where the full chroma does not exist at that tone, the most that does.
function tone(hue, chroma, t) {
    if (t <= 0)
        return "#000000";
    if (t >= 100)
        return "#ffffff";
    let lo = 0, hi = Math.max(0, chroma);
    if (_inGamut(_lchToLinear(t, hi, hue)))
        return hex(_clampRgb(_lchToLinear(t, hi, hue)));
    for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2;
        if (_inGamut(_lchToLinear(t, mid, hue)))
            lo = mid;
        else
            hi = mid;
    }
    return hex(_clampRgb(_lchToLinear(t, lo, hue)));
}

// ---- light or dark ----------------------------------------------------

// Whether a background reads as dark: below the middle of L*.
function isDark(value) {
    return lab(value).l < 50;
}

// ---- the scheme --------------------------------------------------------

// Every role, as "#rrggbb", for one seed and one of the two schemes. The
// tones are Material 3's; the chromas its "tonal spot" ones, except that
// the primary keeps a vivid seed's own chroma, so it still looks like the
// seed. A seed with almost no
// color gives an almost colorless scheme rather than an arbitrary hue.
function scheme(seedColor, dark) {
    const s = lch(normalize(seedColor, "#4f60c8"));
    const h = s.h;
    const gray = s.c < 6;
    const pc = gray ? s.c : Math.max(s.c, 36);

    const P = t => tone(h, pc, t);
    const S = t => tone(h, gray ? s.c : 16, t);
    const T = t => tone((h + 60) % 360, gray ? s.c : 24, t);
    const N = t => tone(h, gray ? 0 : 4, t);
    const V = t => tone(h, gray ? 0 : 9, t);
    const E = t => tone(32, 70, t);
    const G = t => tone(145, 48, t);
    const W = t => tone(75, 64, t);

    const d = dark === true;
    return {
        dark: d,
        primary: P(d ? 80 : 40),
        onPrimary: P(d ? 20 : 100),
        primaryContainer: P(d ? 30 : 90),
        onPrimaryContainer: P(d ? 90 : 10),
        secondary: S(d ? 80 : 40),
        onSecondary: S(d ? 20 : 100),
        secondaryContainer: S(d ? 30 : 90),
        onSecondaryContainer: S(d ? 90 : 10),
        tertiary: T(d ? 80 : 40),
        tertiaryContainer: T(d ? 30 : 90),
        onTertiaryContainer: T(d ? 90 : 10),
        error: E(d ? 80 : 40),
        onError: E(d ? 20 : 100),
        errorContainer: E(d ? 30 : 90),
        onErrorContainer: E(d ? 90 : 10),
        positive: G(d ? 80 : 40),
        warning: W(d ? 80 : 50),
        surface: N(d ? 6 : 98),
        surfaceDim: N(d ? 6 : 87),
        surfaceBright: N(d ? 24 : 98),
        surfaceContainerLowest: N(d ? 4 : 100),
        surfaceContainerLow: N(d ? 10 : 96),
        surfaceContainer: N(d ? 12 : 94),
        surfaceContainerHigh: N(d ? 17 : 92),
        surfaceContainerHighest: N(d ? 22 : 90),
        onSurface: N(d ? 90 : 10),
        surfaceVariant: V(d ? 30 : 90),
        onSurfaceVariant: V(d ? 80 : 30),
        outline: V(d ? 60 : 50),
        outlineVariant: V(d ? 30 : 80),
        inverseSurface: N(d ? 90 : 20),
        inverseOnSurface: N(d ? 20 : 95),
        inversePrimary: P(d ? 40 : 80),
        scrim: "#000000",
        shadow: "#000000"
    };
}
