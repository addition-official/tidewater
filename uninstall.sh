#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Undo install.sh: restores the panels and colours from before Tidewater last
# went on your panel, and removes the widgets, fonts and colour schemes it added.
#
#   ./uninstall.sh              restore the setup from before Tidewater was installed
#   ./uninstall.sh --latest     restore from the most recent backup instead
#                               (e.g. the panel you had before a failed --rebuild)
#   ./uninstall.sh --keep-widget  restore panels/colours but leave the widgets installed
#
# Your setup as it is right now is saved first (…/backups/<time>-pre-uninstall),
# so nothing is lost. Backups are never deleted; they stay in
# ~/.local/share/tidewater/backups.

set -euo pipefail
ID=tidewater
ROOT="$HOME/.local/share/tidewater/backups"
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

PICK=first
KEEP=0
for a in "$@"; do
    case $a in
        --latest) PICK=latest ;;
        --keep-widget) KEEP=1 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

[ "$(id -u)" != 0 ] || die "Run this as your normal user, not with sudo."
[ -d "$ROOT" ] || die "No backups found in $ROOT"
HERE=$(dirname "$(readlink -f "$0")")

# Backups made by install.sh, oldest first (not our own pre-uninstall snapshots).
# Ordered by when they were made (names switched from local time to UTC once,
# so sorting by name could mix old and new ones up).
backups() { ls -1dtr "$ROOT"/*/ 2>/dev/null | sed 's:/$::' | grep -v -- '-pre-uninstall$' || true; }
if [ "$PICK" = latest ]; then
    B=$(backups | tail -1)
else
    # The newest backup taken just before Tidewater went on the panel. (Older
    # installs didn't mark them: then the oldest backup, as before.)
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

say "Stopping Plasma's shell for a moment"
# Plasma writes its settings when it quits: restoring under a running Plasma
# would be overwritten, so don't go on unless it really stopped.
bash "$HERE/restart-plasma.sh" stop || die "Could not stop Plasma, so nothing was changed. Try again, or log out and in first."
# From here on, whatever happens, Plasma comes back up.
trap 'bash "$HERE/restart-plasma.sh" start >/dev/null 2>&1 || true' EXIT
sleep 1

# Save the setup as it is now, so this uninstall can be undone too.
NOW="$ROOT/$(date -u +%Y%m%d-%H%M%S)-pre-uninstall"
mkdir -p "$NOW"
for f in $FILES; do [ -f "$HOME/.config/$f" ] && cp -a "$HOME/.config/$f" "$NOW/"; done
for f in $GTK; do
    if [ -f "$HOME/.config/$f" ]; then mkdir -p "$NOW/gtk/$(dirname "$f")"; cp -a "$HOME/.config/$f" "$NOW/gtk/$f"; fi
done
say "Saved your current setup to $NOW"

# Panels. A file missing from the backup didn't exist before the install, so
# the current one (Tidewater' panel) goes; Plasma then starts with its default.
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
    have fc-cache && fc-cache -f >/dev/null 2>&1 || true
fi

say "Starting Plasma again"
bash "$HERE/restart-plasma.sh" start || warn "Plasma didn't start again: run  kstart plasmashell"

# Colours: the goal is your original kdeglobals, byte for byte.
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
    say "Restored your original colours${scheme:+ ($scheme)}"
else
    # No kdeglobals before the install: go back to Plasma's default scheme
    # rather than keep pointing at the Tidewater one, which is removed below.
    if have plasma-apply-colorscheme; then
        plasma-apply-colorscheme BreezeLight >/dev/null 2>&1 || true
        warn "Your backup had no colour settings, so Plasma's default colours (Breeze) were applied."
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
fi

if [ "$KEEP" = 0 ]; then
    rm -f "$HOME/.local/share/color-schemes/TidewaterLight.colors" "$HOME/.local/share/color-schemes/TidewaterDark.colors"
fi

say "All back to how it was. (Backups kept in $ROOT)"
