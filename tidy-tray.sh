#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Take Plasma's own network, Bluetooth, brightness, volume and notification
# icons out of the system tray (Tidewater shows its own). Network, Bluetooth
# and brightness are switched off in the tray; volume and notifications stay
# running, hidden, because volume keys and pop-ups need them. Wi-Fi password
# prompts keep working. Safe to run any time:  bash ./tidy-tray.sh
#
# Plasma is stopped for a moment and the setting is written straight into the
# tray's saved config, which is the one place Plasma always reads at start.

set -euo pipefail
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
# Switched off entirely: nothing else depends on these tray entries (Wi-Fi
# password prompts and Bluetooth pairing come from background services).
OFF="org.kde.plasma.networkmanagement org.kde.plasma.bluetooth org.kde.plasma.brightness"
# Kept running but hidden: volume keys and notification pop-ups need them.
HIDE="org.kde.plasma.volume org.kde.plasma.notifications"
[ -f "$RC" ] || die "No Plasma panel config found at $RC"

# Whatever happens below, Plasma comes back up.
HERE=$(dirname "$(readlink -f "$0")")
restart_plasma() { bash "$HERE/restart-plasma.sh" start; }
trap restart_plasma EXIT

# Stop Plasma first: it only writes a new panel's layout to disk every few
# seconds (and when it quits), so reading before that finds the old trays.
bash "$HERE/restart-plasma.sh" stop || die "Could not stop Plasma to change the tray"

find_trays() {
    # Prints the config path of every tray, e.g. "Containments 2 Applets 5".
    # Plasma 6.6+ keeps the tray as a widget inside the panel's section
    # ([Containments][2][Applets][5]); older Plasma 6 as a section of its own
    # ([Containments][8], plugin org.kde.plasma.private.systemtray).
    awk '
        /^\[/ {
            path = ""
            if ($0 ~ /^\[Containments\]\[[0-9]+\](\[Applets\]\[[0-9]+\])?[ \t\r]*$/) {
                path = $0
                gsub(/[\[\] \t\r]+/, " ", path)
                sub(/^ /, "", path); sub(/ $/, "", path)
            }
            next
        }
        path != "" && $0 ~ /^plugin=org\.kde\.plasma\.(private\.)?systemtray[ \t\r]*$/ { print path }
    ' "$RC" | sort -u
}
trays=$(find_trays)
if [ -z "$trays" ]; then
    say "No system tray found in your panels, so there is nothing to tidy."
    exit 0
fi

# list helpers: comma-separated lists as KConfig stores them
has()    { case ",$1," in *",$2,"*) return 0 ;; esac; return 1; }
add()    { if has "$1" "$2"; then echo "$1"; else echo "${1:+$1,}$2"; fi; }
remove() { echo ",$1," | sed "s/,$2,/,/g; s/^,//; s/,$//"; }

n=0
while read -r tray; do
    [ -n "$tray" ] || continue
    groups=()
    for part in $tray General; do groups+=(--group "$part"); done
    get() { kreadconfig6 --file "$RC" "${groups[@]}" --key "$1"; }
    put() { kwriteconfig6 --file "$RC" "${groups[@]}" --key "$1" "$2"; }

    extra=$(get extraItems); known=$(get knownItems); hidden=$(get hiddenItems); shown=$(get shownItems)
    for item in $OFF; do
        extra=$(remove "$extra" "$item")     # not enabled...
        known=$(add "$known" "$item")        # ...and known, so Plasma won't re-enable it
    done
    for item in $OFF $HIDE; do
        hidden=$(add "$hidden" "$item")
        shown=$(remove "$shown" "$item")     # "always shown" would beat "hidden"
    done
    put extraItems "$extra"; put knownItems "$known"; put hiddenItems "$hidden"; put shownItems "$shown"
    n=$((n + 1))
done <<< "$trays"

restart_plasma
say "Tidied $n system tray(s): Plasma's network, Bluetooth and brightness icons are off; volume and bell are hidden"
