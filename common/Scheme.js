.pragma library
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Marius Gabriel Lupu (remapprShell, https://github.com/Wolffyx/remapprShell)
// SPDX-FileCopyrightText: 2026 addition-official
// Taken from remapprShell and modified for Tidewater by addition-official, 2026.
// Colour engine: builds every colour role from one seed colour, light or dark.

    // ---- colour in, colour out -------------------------------------------

    // "#rgb", "#rrggbb", "#aarrggbb" (alpha ignored), "r,g,b" (as kdeglobals
    // writes them) or "oklch(l c h)" (as the design names its accents). Null
    // for anything else.
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
        m = /^oklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)(?:deg)?\s*\)$/.exec(s);
        if (m) {
            const l = m[2] === "%" ? parseFloat(m[1]) / 100 : parseFloat(m[1]);
            return _clampRgb(_oklchToLinear(l, parseFloat(m[3]), parseFloat(m[4])));
        }
        return null;
    }

    function hex(rgb) {
        const h = v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0");
        return `#${h(rgb.r)}${h(rgb.g)}${h(rgb.b)}`;
    }

    // Any colour this file accepts, as "#rrggbb"; the fallback when it is none.
    function normalise(value, fallback) {
        const rgb = parse(value);
        return rgb ? hex(rgb) : fallback;
    }

    // "#aarrggbb", which a QML colour accepts. For translucent surfaces.
    function withAlpha(value, alpha) {
        const rgb = parse(value) ?? { r: 0, g: 0, b: 0 };
        const a = Math.round(Math.max(0, Math.min(1, alpha)) * 255).toString(16).padStart(2, "0");
        return `#${a}${hex(rgb).slice(1)}`;
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

    // Linear sRGB for a CIELAB LCh colour, possibly outside [0, 1].
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

    // Linear sRGB for an OKLCH colour (Ottosson's OKLab), possibly outside
    // [0, 1]. Only for reading the design's accents, which are named in it.
    function _oklchToLinear(l, c, h) {
        const a = c * Math.cos(h * Math.PI / 180), b = c * Math.sin(h * Math.PI / 180);
        const l_ = l + 0.3963377774 * a + 0.2158037573 * b;
        const m_ = l - 0.1055613458 * a - 0.0638541728 * b;
        const s_ = l - 0.0894841775 * a - 1.2914855480 * b;
        const L = l_ * l_ * l_, M = m_ * m_ * m_, S = s_ * s_ * s_;
        return { r: 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
                 g: -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
                 b: -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S };
    }

    // ---- tones -------------------------------------------------------------

    // The colour of `hue` and at most `chroma` whose L* is exactly `tone`.
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

    // ---- contrast ----------------------------------------------------------

    function luminance(value) {
        const rgb = parse(value) ?? { r: 0, g: 0, b: 0 };
        return 0.2126 * _toLinear(rgb.r) + 0.7152 * _toLinear(rgb.g) + 0.0722 * _toLinear(rgb.b);
    }

    // WCAG's contrast ratio, 1 to 21.
    function contrast(a, b) {
        const la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Whether a background reads as dark: below the middle of L*.
    function isDark(value) {
        return lab(value).l < 50;
    }

    // ---- choosing ----------------------------------------------------------

    // "light", "dark", or "auto": the Plasma colour scheme's own background
    // decides, so the shell turns dark exactly when the rest of the desktop
    // does -- by hand in System Settings, or at sunset when Plasma switches
    // between a light and a dark global theme by itself. Anything else is
    // "auto".
    // `daylight` is KWin's Night Light, when it has an opinion: true while the
    // sun is up, false after sunset, undefined when Night Light is off or not
    // there. With one, "auto" means day and night on the schedule the desktop
    // already warms the screen by. Without one there is no schedule to follow,
    // so it falls back to the colour scheme's own darkness -- which is what
    // auto meant before, and still means on a desktop with Night Light off.
    function resolveMode(mode, systemBackground, daylight) {
        if (mode === "light" || mode === "dark")
            return mode;
        if (daylight === true)
            return "light";
        if (daylight === false)
            return "dark";
        return isDark(normalise(systemBackground, "#ffffff")) ? "dark" : "light";
    }

    // The design's four accents, as it names them, and Plasma's own.
    var accents = ({
        "blue": "oklch(.55 .13 262)",
        "teal": "oklch(.55 .13 190)",
        "magenta": "oklch(.55 .13 320)",
        "orange": "oklch(.55 .13 60)"
    })

    // The seed for an accent name. "plasma" is Plasma's accent colour, which
    // System Settings can also take from the wallpaper; a colour given
    // directly is used as it is. Anything unusable is the design's blue.
    function seed(accent, systemAccent) {
        const fallback = normalise(accents.blue, "#4f60c8");
        if (accent === "plasma")
            return normalise(systemAccent, fallback);
        if (accents[accent] !== undefined)
            return normalise(accents[accent], fallback);
        return normalise(accent, fallback);
    }

    // ---- the scheme --------------------------------------------------------

    // Every role, as "#rrggbb", for one seed and one of the two schemes. The
    // tones are Material 3's; the chromas its "tonal spot" ones, except that
    // the primary keeps a vivid seed's own chroma -- the accent a person
    // picked should look like the one they picked. A seed with almost no
    // colour gives an almost colourless scheme rather than an arbitrary hue.
    function scheme(seedColour, dark) {
        const s = lch(normalise(seedColour, "#4f60c8"));
        const h = s.h;
        const grey = s.c < 6;
        const pc = grey ? s.c : Math.max(s.c, 36);

        const P = t => tone(h, pc, t);
        const S = t => tone(h, grey ? s.c : 16, t);
        const T = t => tone((h + 60) % 360, grey ? s.c : 24, t);
        const N = t => tone(h, grey ? 0 : 4, t);
        const V = t => tone(h, grey ? 0 : 9, t);
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
