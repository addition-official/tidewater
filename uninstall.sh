#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Undo install.sh: restores the panels and colors from before Tidewater last
# went on your panel, and removes the widgets, fonts and color schemes it added.
#
#   ./uninstall.sh              restore the setup from before Tidewater was installed
#   ./uninstall.sh --latest     restore from the most recent backup instead
#                               (e.g. the panel you had before a failed --rebuild)
#   ./uninstall.sh --keep-widget  restore panels/colors but leave the widgets installed
#                               (on its own, or with --latest)
#   ./uninstall.sh --purge      uninstall, then delete every trace of Tidewater too:
#                               its backups, settings module, caches and state files.
#                               Lists what goes and asks you to type "delete" first.
#                               This can't be undone. (Also with --latest.)
#   ./uninstall.sh --purge --yes  the same without asking (for scripts)
#
# Without --purge, your setup as it is right now is saved first
# (…/backups/<time>-pre-uninstall), so nothing is lost. Backups are never
# deleted; they stay in ~/.local/share/tidewater/backups.

set -euo pipefail
SELF=$(readlink -f "$0")
ID=tidewater
ROOT="$HOME/.local/share/tidewater/backups"
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

PICK=first
KEEP=0
PURGE=0
YES=0
for a in "$@"; do
    case $a in
        --latest) PICK=latest ;;
        --keep-widget) KEEP=1 ;;
        --purge) PURGE=1 ;;
        --yes) YES=1 ;;          # long form only, on purpose: no -y
        # the usage lines at the top of this file, without the leading "# "
        -h|--help) sed -n '5,/^$/p' "$SELF" | sed '/^$/d; s/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

if [ "$PURGE" = 1 ] && [ "$KEEP" = 1 ]; then
    echo "--purge removes the widgets too, so it can't go with --keep-widget." >&2; exit 2
fi
if [ "$YES" = 1 ] && [ "$PURGE" = 0 ]; then
    echo "--yes only goes with --purge (a plain uninstall doesn't ask)." >&2; exit 2
fi

[ "$(id -u)" != 0 ] || die "Run this as your normal user, not with sudo."
[ -d "$ROOT" ] || die "No backups found in $ROOT"
HERE=$(dirname "$SELF")

# Backups made by install.sh, oldest first (not our own pre-uninstall snapshots),
# ordered by when they were made.
backups() { ls -1dtr "$ROOT"/*/ 2>/dev/null | sed 's:/$::' | grep -v -- '-pre-uninstall$' || true; }
if [ "$PICK" = latest ]; then
    B=$(backups | tail -1)
else
    # The newest backup taken just before Tidewater went on the panel (or, if
    # none is marked as such, the oldest backup).
    B=$(backups | while read -r d; do if [ -f "$d/pre-install" ]; then echo "$d"; fi; done | tail -1)
    [ -n "$B" ] || B=$(backups | head -1)
fi
[ -n "$B" ] || die "No backups found in $ROOT"

# Removing the widgets but restoring a panel that still uses them would leave
# a broken panel: then take the newest backup from before Tidewater instead.
uses_tidewater() { grep -q '^plugin=tidewater\.' "$1/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; }
if [ "$KEEP" = 0 ] && uses_tidewater "$B"; then
    C=$(backups | while read -r d; do if ! uses_tidewater "$d"; then echo "$d"; fi; done | tail -1)
    [ -n "$C" ] || die "Every backup's panel uses Tidewater, and removing it would leave a broken panel. Use --keep-widget to restore one anyway."
    say "The most recent backup still uses Tidewater's panel, so using the newest one from before it"
    B=$C
fi
say "Restoring from $B"

FILES="plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kdeglobals"
GTK="gtk-3.0/settings.ini gtk-3.0/colors.css gtk-4.0/settings.ini gtk-4.0/colors.css xsettingsd/xsettingsd.conf"

# ---- --purge: what goes, and asking first --------------------------------------
# Everything Tidewater itself writes, and nothing else. (Its widgets, Alt+Tab
# switcher, fonts and color schemes go in the normal uninstall below; the
# folders of widgets and switchers are listed here too, as a safety net.)
DATA="$HOME/.local/share"
XDATA="${XDG_DATA_HOME:-$HOME/.local/share}"
XCACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
QMLCACHES=()          # Plasma's compiled copies of widget code (Plasma rebuilds them)
PURGE_LIST=()
# Adds the paths that exist (each once) to the list. An unmatched pattern stays
# as its own text, which doesn't exist, so it is skipped.
add() {
    local p q
    for p in "$@"; do
        [ -e "$p" ] || [ -L "$p" ] || continue
        for q in "${PURGE_LIST[@]}"; do [ "$q" = "$p" ] && continue 2; done
        PURGE_LIST+=("$p")
    done
}
if [ "$PURGE" = 1 ]; then
    # The widgets and switcher (all versions), fonts and color schemes
    add "$DATA"/plasma/plasmoids/tidewater.*
    add "$DATA"/kwin/tabbox/tidewater-switcher* "$DATA"/kwin-wayland/tabbox/tidewater-switcher*
    add "$DATA/fonts/tidewater"
    add "$DATA/color-schemes/TidewaterLight.colors" "$DATA/color-schemes/TidewaterDark.colors"
    # Tidewater's own folder: backups (with the snapshot this run takes), the
    # last build's layout and the shared settings module
    add "$DATA/tidewater" "$XDATA/tidewater"
    # The status and start widgets' state files: in the runtime folder, or in
    # a cache folder of our own when there is none
    if [ -n "${XDG_RUNTIME_DIR:-}" ]; then add "$XDG_RUNTIME_DIR"/tidewater-*; fi
    add "$HOME/.cache/tidewater" "$XCACHE/tidewater"
    n=${#PURGE_LIST[@]}
    add "$HOME/.cache/plasmashell/qmlcache" "$XCACHE/plasmashell/qmlcache"
    QMLCACHES=("${PURGE_LIST[@]:$n}")

    echo
    echo "--purge restores your panels, colors and Alt+Tab from:"
    echo "    $B"
    echo "and then deletes these for good:"
    if [ "${#PURGE_LIST[@]}" -gt 0 ]; then printf '    %s\n' "${PURGE_LIST[@]}"; else echo "    (nothing else found)"; fi
    echo "(plus a snapshot of your current setup, which this run saves on the way)"
    echo
    warn "Your Tidewater backups are deleted too, so this can NOT be undone."
    if [ "$YES" = 0 ]; then
        [ -t 0 ] || die "Not asking without a terminal, so nothing was changed. To purge from a script, add --yes."
        printf 'Type "delete" to go ahead (anything else stops here): '
        answer=""
        read -r answer || true
        if [ "$answer" != delete ]; then
            say "Stopped. Nothing was changed."
            exit 1
        fi
    fi
fi

# Deletes one --purge path. A guard on top of the list above: only a full
# path whose last part has one of our names (or is Plasma's qmlcache) goes.
purge_rm() {
    local p=$1
    case "$p" in
        /*/tidewater|/*/tidewater.*|/*/tidewater-*|/*/TidewaterLight.colors|/*/TidewaterDark.colors) ;;
        /*/plasmashell/qmlcache) ;;
        *) warn "Not deleting '$p'"; return 0 ;;
    esac
    rm -rf -- "$p"
    # Then the folders it was in, while they are left empty (such as
    # ~/.local/share/plasma/plasmoids). Never the base folders themselves.
    local d=${p%/*}
    while [ -n "$d" ] && [ "$d" != / ]; do
        case "$d" in "$HOME"|"$HOME/.local"|"$DATA"|"$XDATA"|"$HOME/.cache"|"$XCACHE"|"${XDG_RUNTIME_DIR:-/}") break ;; esac
        rmdir -- "$d" 2>/dev/null || break
        d=${d%/*}
    done
}

say "Stopping Plasma's shell for a moment"
# Plasma writes its settings when it quits: restoring under a running Plasma
# would be overwritten, so don't go on unless it really stopped.
bash "$HERE/restart-plasma.sh" stop || die "Could not stop Plasma, so nothing was changed. Try again, or log out and in first."
# From here on, whatever happens, Plasma comes back up.
trap 'bash "$HERE/restart-plasma.sh" start >/dev/null 2>&1 || true' EXIT
sleep 1

# Save the setup as it is now, so this uninstall can be undone too.
while :; do
    NOW="$ROOT/$(date -u +%Y%m%d-%H%M%S)-pre-uninstall"
    mkdir "$NOW" 2>/dev/null && break       # never reuse (or overwrite) a snapshot
    sleep 1
done
for f in $FILES; do [ -f "$HOME/.config/$f" ] && cp -a "$HOME/.config/$f" "$NOW/"; done
for f in $GTK; do
    if [ -f "$HOME/.config/$f" ]; then mkdir -p "$NOW/gtk/$(dirname "$f")"; cp -a "$HOME/.config/$f" "$NOW/gtk/$f"; fi
done
say "Saved your current setup to $NOW"

# Panels. A file missing from the backup didn't exist before the install, so
# the current one (Tidewater's panel) goes; Plasma then starts with its default.
for f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc; do
    if [ -f "$B/$f" ]; then cp -a "$B/$f" "$HOME/.config/"; else rm -f "$HOME/.config/$f"; fi
done

if [ "$KEEP" = 0 ] && have kpackagetool6; then
    n=0
    for id in $(kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -o "$ID\.[a-z]*" | sort -u); do
        kpackagetool6 -t Plasma/Applet -r "$id" >/dev/null 2>&1 && n=$((n + 1))
    done
    say "Removed $n Tidewater widgets"
    for id in $(kpackagetool6 -t KWin/WindowSwitcher -l 2>/dev/null | grep -o 'tidewater-switcher[A-Za-z0-9-]*' | sort -u); do
        kpackagetool6 -t KWin/WindowSwitcher -r "$id" >/dev/null 2>&1 || true
    done
    rm -rf "$HOME/.local/share/fonts/tidewater"
    # the shared settings module (never the backups next to it)
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/tidewater/qml"
    have fc-cache && fc-cache -f >/dev/null 2>&1 || true
fi
# Plasma's compiled copies of widget code: best dropped while it is stopped.
if [ "$PURGE" = 1 ]; then
    for q in "${QMLCACHES[@]}"; do purge_rm "$q"; done
fi

say "Starting Plasma again"
bash "$HERE/restart-plasma.sh" start || warn "Plasma didn't start again: run  kstart plasmashell"

# Colors: the goal is your original kdeglobals, byte for byte.
#
# Copying the file alone doesn't tell running apps to repaint, and
# plasma-apply-colorscheme alone isn't exact. So: work out which scheme the
# backup really used, apply it (running apps repaint), then copy the original
# file over the top so every key is exactly what it was.
if [ -f "$B/kdeglobals" ]; then
    scheme=""
    if have kreadconfig6; then
        scheme=$(kreadconfig6 --file "$B/kdeglobals" --group General --key ColorScheme)
        if [ -z "$scheme" ]; then
            # No explicit scheme: it came from the global theme's defaults.
            laf=$(kreadconfig6 --file "$B/kdeglobals" --group KDE --key LookAndFeelPackage)
            [ -n "$laf" ] || laf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
            for d in "$HOME/.local/share/plasma/look-and-feel/$laf" "/usr/share/plasma/look-and-feel/$laf"; do
                if [ -f "$d/contents/defaults" ]; then
                    scheme=$(kreadconfig6 --file "$d/contents/defaults" --group kdeglobals --group General --key ColorScheme)
                    break
                fi
            done
        fi
    fi

    if [ -n "$scheme" ] && have plasma-apply-colorscheme; then
        # Applying the scheme that's already current is a no-op, so step off it first.
        other=BreezeClassic; [ "$scheme" = BreezeClassic ] && other=BreezeLight
        plasma-apply-colorscheme "$other" >/dev/null 2>&1 || true
        plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 || true
    fi
    cp -a "$B/kdeglobals" "$HOME/.config/kdeglobals"
    say "Restored your original colors${scheme:+ ($scheme)}"
else
    # No kdeglobals before the install: go back to Plasma's default scheme
    # rather than keep pointing at the Tidewater one, which is removed below.
    if have plasma-apply-colorscheme; then
        plasma-apply-colorscheme BreezeLight >/dev/null 2>&1 || true
        warn "Your backup had no color settings, so Plasma's default colors (Breeze) were applied."
    fi
fi
for f in $GTK; do
    if [ -f "$B/gtk/$f" ]; then mkdir -p "$HOME/.config/$(dirname "$f")"; cp -a "$B/gtk/$f" "$HOME/.config/$f"; fi
done
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
# Alt+Tab: back to what it was in the chosen backup. If that was ours and the
# widgets are being removed, the earliest recorded switcher that wasn't ours.
old=""
while read -r d; do
    [ -f "$d/tabbox-layout" ] || continue
    v=$(cat "$d/tabbox-layout")
    case "$v" in tidewater-switcher*)
        # widgets kept (--keep-widget): leave Alt+Tab on the current Tidewater
        # version; otherwise ours is being removed, so look further back
        [ "$KEEP" = 1 ] && break
        continue ;;
    esac
    old=$v; break
done < <(echo "$B"; backups)
if [ -n "$old" ] && have kwriteconfig6; then
    if [ "$old" = unset ]; then
        kwriteconfig6 --file kwinrc --group TabBox --key LayoutName --delete
    else
        kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "$old"
    fi
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
    say "Restored your Alt+Tab switcher"
elif [ "$KEEP" = 0 ] && have kwriteconfig6; then
    # Nothing to go back to, but ours is being removed: Plasma's default, rather
    # than Alt+Tab pointing at a switcher that is gone.
    case "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null || true)" in
        tidewater-switcher*)
            kwriteconfig6 --file kwinrc --group TabBox --key LayoutName --delete
            busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
            say "Alt+Tab is back to Plasma's default switcher" ;;
    esac
fi

if [ "$KEEP" = 0 ]; then
    rm -f "$HOME/.local/share/color-schemes/TidewaterLight.colors" "$HOME/.local/share/color-schemes/TidewaterDark.colors"
fi

if [ "$PURGE" = 1 ]; then
    for p in "${PURGE_LIST[@]}"; do purge_rm "$p"; done
    # anything that appeared while this ran (such as the snapshot above)
    for p in "$DATA/tidewater" "$XDATA/tidewater"; do purge_rm "$p"; done
    say "All back to how it was, and every trace of Tidewater is gone."
    exit 0
fi
say "All back to how it was. (Backups kept in $ROOT)"
