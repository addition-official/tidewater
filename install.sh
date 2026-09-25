#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Tidewater: a desktop for Plasma 6.
#
#   ./install.sh                 first time: builds the panel. After that: just
#                                updates the widgets, keeping your panel and settings
#   ./install.sh --rebuild       rebuild the panel (your settings are carried over)
#   ./install.sh --full          rebuild as a full-width bar (the default style)
#   ./install.sh --floating      rebuild as a floating bar with rounded ends
#   ./install.sh --islands       rebuild as three floating islands
#   ./install.sh --all-screens   a bar on every monitor (default: primary only)
#   ./install.sh --light | --dark    force a mode (default: keep yours)
#   ./install.sh --widgets-only  install the widgets and fonts, leave panels/colours alone
#
# Everything goes into your home folder. No sudo. Before touching anything it
# backs up your panels and colours to ~/.local/share/tidewater/backups, and
# ./uninstall.sh puts back exactly what was there before your first install.

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

STYLE="full"
SCREENS="primary"
MODE="keep"
PANELS=1
REBUILD=0
for a in "$@"; do
    case $a in
        --full) STYLE="full"; REBUILD=1 ;;
        --floating) STYLE="floating"; REBUILD=1 ;;
        --islands) STYLE="islands"; REBUILD=1 ;;
        --rebuild) REBUILD=1 ;;
        --all-screens) SCREENS="all" ;;
        --light) MODE="light" ;;
        --dark) MODE="dark" ;;
        --widgets-only|--widget-only) PANELS=0 ;;
        -h|--help) sed -n 4,19p "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- checks ------------------------------------------------------------------
[ "$(id -u)" != 0 ] || die "Run this as your normal user, not with sudo."
have kpackagetool6 || die "kpackagetool6 not found. Is this Plasma 6?"
have busctl || die "busctl not found."
major=$(plasmashell --version 2>/dev/null | grep -o '[0-9]\+' | head -1 || true)
[ "${major:-0}" -ge 6 ] || die "Plasma 6 is required (found: $(plasmashell --version 2>/dev/null))."

for t in nmcli:Wi-Fi/Ethernet wpctl:volume/microphone bluetoothctl:Bluetooth kreadconfig6:"do not disturb"; do
    have "${t%%:*}" || warn "${t%%:*} is missing, so the ${t#*:} tiles will show as unavailable."
done
have python3 || warn "python3 is missing, so the start menu will be empty and --rebuild can't carry your settings over. (sudo apt install python3)"
have kwriteconfig6 || die "kwriteconfig6 not found. Is this Plasma 6?"

RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
installed=0
grep -q '^plugin=tidewater\.' "$RC" 2>/dev/null && installed=1

# ---- backup (never overwritten, never deleted) --------------------------------
# Named in UTC so they sort in true order across time zone / DST changes.
ROOT="$HOME/.local/share/tidewater/backups"
mkdir -p "$ROOT"
while :; do
    BACKUP="$ROOT/$(date -u +%Y%m%d-%H%M%S)"
    mkdir "$BACKUP" 2>/dev/null && break     # never reuse (or overwrite) a backup
    sleep 1
done
# The state before Tidewater went on the panel: what ./uninstall.sh restores.
# (Not when the colours are already ours: that's a retry after a first install
# that stopped halfway, and the real "before" is an earlier backup.)
cur_scheme=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)
if [ "$installed" = 0 ] && [ "$PANELS" = 1 ]; then
    case "$cur_scheme" in Tidewater*) ;; *) touch "$BACKUP/pre-install" ;; esac
fi
for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kdeglobals; do
    [ -f "$HOME/.config/$f" ] && cp -a "$HOME/.config/$f" "$BACKUP/"
done
for f in gtk-3.0/settings.ini gtk-3.0/colors.css gtk-4.0/settings.ini gtk-4.0/colors.css xsettingsd/xsettingsd.conf; do
    if [ -f "$HOME/.config/$f" ]; then
        mkdir -p "$BACKUP/gtk/$(dirname "$f")"
        cp -a "$HOME/.config/$f" "$BACKUP/gtk/$f"
    fi
done
# Alt+Tab's current look, so uninstall can put it back ("unset" = Plasma's default)
tabbox=$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null || true)
echo "${tabbox:-unset}" > "$BACKUP/tabbox-layout"
say "Backed up your current setup to $BACKUP"

# ---- fonts (only our widgets use them; your app fonts don't change) -----------
FONTDIR="$HOME/.local/share/fonts/tidewater"
mkdir -p "$FONTDIR"
cp fonts/*.ttf "$FONTDIR/"
have fc-cache && fc-cache -f "$FONTDIR" >/dev/null 2>&1 || true
say "Installed fonts: Rubik, Material Symbols Rounded"

# ---- widgets -----------------------------------------------------------------
BUILD=$(mktemp -d)
SWBUILD=$(mktemp -d)
trap 'rm -rf "$BUILD" "$SWBUILD"' EXIT
for dir in plasmoids/*/; do
    name=$(basename "$dir")
    cp -r "$dir" "$BUILD/$name"
    mkdir -p "$BUILD/$name/contents/ui/common"
    cp common/* "$BUILD/$name/contents/ui/common/"
    id=$(sed -n 's/.*"Id": "\([^"]*\)".*/\1/p' "$dir/metadata.json")
    # Remove and reinstall rather than "upgrade": an upgrade can leave the old
    # files in place. Widget settings live in Plasma's config, not here.
    kpackagetool6 -t Plasma/Applet -r "$id" >/dev/null 2>&1 || true
    if ! kpackagetool6 -t Plasma/Applet -i "$BUILD/$name" >/dev/null 2>&1; then
        kpackagetool6 -t Plasma/Applet -u "$BUILD/$name" >/dev/null 2>&1 \
            || { warn "$id could not be installed"; continue; }
    fi
    # Check the installed copy really is this version.
    dest="$HOME/.local/share/plasma/plasmoids/$id/contents/ui/main.qml"
    if ! cmp -s "$BUILD/$name/contents/ui/main.qml" "$dest"; then
        warn "$id did not install cleanly (its files differ from this version)"
    fi
done
# Plasma keeps compiled copies of widget code; drop them so the new code is used.
rm -rf "$HOME/.cache/plasmashell/qmlcache"
say "Installed $(ls -d plasmoids/*/ | wc -l) widgets"

# ---- Alt+Tab: three layouts (row is the default) ---------------
# KWin keeps a switcher's code in memory, by package name, until you log out.
# So each version is installed under a name carrying a hash of its contents
# (tidewater-switcher-1a2b3c4d), and KWin is pointed at the new name.
VER=$(cat switcher/*/contents/ui/main.qml switcher/*/metadata.json | sha1sum | cut -c1-8)
cur_switcher=$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null || true)
variant=""
case "$cur_switcher" in *-grid) variant="-grid" ;; *-icons) variant="-icons" ;; esac
[ -d "switcher/tidewater-switcher$variant" ] || variant=""
using_ours=0
case "$cur_switcher" in tidewater-switcher*) using_ours=1 ;; esac

for old in $(kpackagetool6 -t KWin/WindowSwitcher -l 2>/dev/null | grep -o 'tidewater-switcher[A-Za-z0-9-]*' | sort -u); do
    case "$old" in *"$VER"*) ;; *) kpackagetool6 -t KWin/WindowSwitcher -r "$old" >/dev/null 2>&1 || true ;; esac
done
for dir in switcher/*/; do
    base=$(basename "$dir")                 # tidewater-switcher, ...-grid, ...-icons
    id="tidewater-switcher-$VER${base#tidewater-switcher}"
    cp -r "$dir" "$SWBUILD/$id"
    sed -i "s/\"Id\": \"[^\"]*\"/\"Id\": \"$id\"/" "$SWBUILD/$id/metadata.json"
    kpackagetool6 -t KWin/WindowSwitcher -s "$id" >/dev/null 2>&1 \
        || kpackagetool6 -t KWin/WindowSwitcher -i "$SWBUILD/$id" >/dev/null
done
SWITCHER="tidewater-switcher-$VER$variant"

use_switcher() {
    kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "$SWITCHER"
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
}
# Already using ours: move to this version, same style (row, grid or icons).
if [ "$using_ours" = 1 ]; then
    use_switcher
    say "Updated the Alt+Tab switcher"
fi

# Alt+Tab: pick ours when Tidewater first goes on the panel; after that it's
# your choice (updates and rebuilds leave it alone).
first_switcher=0
[ "$installed" = 0 ] && first_switcher=1

if [ "$installed" = 1 ] && [ "$REBUILD" = 0 ] && [ "$PANELS" = 1 ]; then
    [ "$first_switcher" = 1 ] && use_switcher
    say "Tidewater is already on your panel, so only the widgets were updated."
    say "Your panel, taskbar settings, pinned apps and colours are unchanged."
    bash ./tidy-tray.sh || warn "Could not tidy the tray (not serious)"
    # restart Plasma so it loads the new widget code
    bash ./restart-plasma.sh || warn "Plasma didn't restart cleanly; run bash ./restart-plasma.sh"
    say "Done. (To rebuild the panel from scratch: ./install.sh --rebuild)"
    exit 0
fi

if [ "$PANELS" = 0 ]; then
    say "Done. Restart Plasma (bash ./restart-plasma.sh), then add them"
    say "from right-click panel > Add Widgets > search \"Tidewater\"."
    exit 0
fi

# ---- colours: light or dark scheme, in the mode you already use --------------------
mkdir -p "$HOME/.local/share/color-schemes"
cp colors/*.colors "$HOME/.local/share/color-schemes/"
if [ "$MODE" = keep ]; then
    bg=$(kreadconfig6 --file kdeglobals --group Colors:Window --key BackgroundNormal 2>/dev/null || true)
    IFS=, read -r r g b <<<"${bg:-239,240,241}"
    # only plain numbers go into $(( )) (bash would run code hidden in text there)
    [[ $r =~ ^[0-9]+$ && $g =~ ^[0-9]+$ && $b =~ ^[0-9]+$ ]] || { r=239; g=240; b=241; }
    # perceived brightness, 0-255
    if [ $(( (r * 299 + g * 587 + b * 114) / 1000 )) -lt 128 ]; then MODE=dark; else MODE=light; fi
fi
if have plasma-apply-colorscheme; then
    if [ "$MODE" = dark ]; then plasma-apply-colorscheme TidewaterDark >/dev/null 2>&1 || true
    else plasma-apply-colorscheme TidewaterLight >/dev/null 2>&1 || true; fi
    say "Applied the $MODE colour scheme"
fi

if [ "$first_switcher" = 1 ]; then
    use_switcher
    say "Alt+Tab now uses the Tidewater switcher"
fi

# ---- restart Plasma (stopping it saves its settings to disk, read below) ----
say "Restarting Plasma so it sees the new widgets (your screen may flicker)"
bash ./restart-plasma.sh || warn "Plasma didn't restart cleanly; run bash ./restart-plasma.sh"
for _ in $(seq 1 60); do
    busctl --user status org.kde.plasmashell >/dev/null 2>&1 && break
    sleep 0.5
done
busctl --user status org.kde.plasmashell >/dev/null 2>&1 \
    || die "Plasma isn't running. Start it with: kstart plasmashell   then run this again."
sleep 2

# ---- carry settings over from the panel being replaced ------------------------
# Taskbar alignment, icon size and pinned apps; start menu pins; clock options.
KEEP=$(python3 - "$RC" <<'PY' 2>/dev/null || echo '{}'
import json, re, sys
LISTS = {"launchers", "pinned"}            # StringList settings
wanted = {"tidewater.tasks": ["alignment", "iconSize", "launchers"],
          "tidewater.start": ["pinned"],
          "tidewater.clock": ["showSeconds", "hourMode", "showDate", "dateFormat"]}

def unescape(v):
    # KConfig escapes: \\ \s \t \n \r (and \, \; inside lists)
    out, i = [], 0
    while i < len(v):
        c = v[i]
        if c == "\\" and i + 1 < len(v):
            n = v[i + 1]
            out.append({"s": " ", "t": "\t", "n": "\n", "r": "\r"}.get(n, n))
            i += 2
        else:
            out.append(c); i += 1
    return "".join(out)

def split_list(v):
    # KConfig escapes a list twice: each item's "\\" and "," as "\\\\" and
    # "\\," (list level), then the whole line again for the file. Undo the
    # file level first, then split on unescaped commas and undo the list level.
    v = unescape(v)
    items, cur, i = [], "", 0
    while i < len(v):
        if v[i] == "\\" and i + 1 < len(v):
            cur += v[i + 1]; i += 2
        elif v[i] == ",":
            items.append(cur); cur = ""; i += 1
        else:
            cur += v[i]; i += 1
    items.append(cur)
    return [x for x in items if x != ""]

keep, plugin_of, order, cur = {}, {}, [], None
try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError:
    lines = []
for line in lines:
    m = re.match(r"^\[Containments\]\[\d+\]\[Applets\]\[(\d+)\](.*)$", line)
    if m:
        cur = (m.group(1), m.group(2))
        continue
    if line.startswith("["):
        cur = None
        continue
    if cur and "=" in line:
        k, v = line.split("=", 1)
        k = re.sub(r"\[\$[a-z]+\]$", "", k)        # drop KConfig flags like [$i]
        if cur[1] == "" and k == "plugin":
            plugin_of[cur[0]] = v
            order.append(cur[0])
        elif cur[1] == "[Configuration][General]":
            keep.setdefault(cur[0], {})[k] = v
out = {}
for aid in order:                          # first panel's widget wins, whole
    plugin = plugin_of[aid]
    if plugin not in wanted or plugin in out:
        continue
    got = {}
    for k in wanted[plugin]:
        if k in keep.get(aid, {}):
            raw = keep[aid][k]
            got[k] = split_list(raw) if k in LISTS else unescape(raw)
    if got:
        out[plugin] = got
print(json.dumps(out))
PY
)
[ "$KEEP" != "{}" ] && say "Carrying over your settings: $(python3 -c 'import json,sys; print(", ".join(k for d in json.loads(sys.argv[1]).values() for k in d))' "$KEEP")"


script=$(sed -e "s/__STYLE__/$STYLE/" -e "s/__SCREENS__/$SCREENS/" layout.js)
script="var KEEP = ${KEEP:-{\}};
$script"
if out=$(busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$script" 2>&1); then
    say "Built the $STYLE panel"
    case "$out" in *"tidewater:"*)
        warn "Some widgets were missing when the panel was built:"
        printf '%s\n' "$out" | grep -o "tidewater: [^\\]*" | sed 's/^/    /' || true
        warn "Run bash ./restart-plasma.sh, then ./install.sh --rebuild" ;;
    esac
else
    err=$out
    warn "Plasma said: $err"
    if [ "$installed" = 1 ]; then
        die "The panel couldn't be built. To get back the panel you had a minute ago: ./uninstall.sh --latest --keep-widget"
    fi
    die "The panel couldn't be built. Nothing is lost: ./uninstall.sh restores your old setup."
fi

# Hide Plasma's duplicate icons in the tray. Done with Plasma stopped, straight
# in its saved config, because that is the one place it always reads at start.
sleep 3
bash ./tidy-tray.sh || warn "Could not tidy the tray; hide duplicates via right-click tray > Configure System Tray"

say "Done! Right-click an empty spot on the taskbar for Taskbar settings (alignment, icon size)."
say "Don't like it? ./uninstall.sh puts everything back exactly."
