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
# Only the trays of panels with Tidewater's status widget on them are changed
# (it shows those icons instead); other panels' trays are left alone.
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
[ "$(id -u)" != 0 ] || die "Run this as your normal user, not with sudo."
[ -f "$RC" ] || die "No Plasma panel config found at $RC"

# Whatever happens below, Plasma comes back up.
HERE=$(dirname "$(readlink -f "$0")")
restart_plasma() { bash "$HERE/restart-plasma.sh" start; }
trap restart_plasma EXIT

# Stop Plasma first: it only writes a new panel's layout to disk every few
# seconds (and when it quits), so reading before that finds the old trays.
bash "$HERE/restart-plasma.sh" stop || die "Could not stop Plasma to change the tray"

find_trays() {
    # Prints the config group of the settings of every tray on a panel that
    # holds tidewater.status, e.g. "Containments 8 General".
    # A tray is a widget in the panel ([Containments][2][Applets][5], plugin
    # org.kde.plasma.systemtray). Up to Plasma 6.5 its settings live in a
    # section of their own that the widget points to with SystrayContainmentId
    # ([Containments][8][General], plugin org.kde.plasma.private.systemtray);
    # from 6.4 the tray widget is a containment itself and keeps them in its own
    # [Containments][2][Applets][5][General] (not [Configuration][General]).
    awk '
        /^\[/ {
            sec = $0; sub(/[ \t\r]+$/, "", sec)
            split(sec, p, /[][]+/)           # "", Containments, 2, Applets, 5, ...
            kind = ""
            if (sec ~ /^\[Containments\]\[[0-9]+\]$/) { kind = "c"; c = p[3] }
            else if (sec ~ /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/) { kind = "a"; c = p[3]; a = p[5] }
            else if (sec ~ /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]\[Configuration\]$/) { kind = "cfg"; a = p[5] }
            next
        }
        {
            line = $0; sub(/[ \t\r]+$/, "", line)
            eq = index(line, "="); if (!eq) next
            k = substr(line, 1, eq - 1); v = substr(line, eq + 1)
            sub(/\[\$[a-z]+\]$/, "", k)         # KConfig flags like [$i]
            if (kind == "c" && k == "plugin") cplugin[c] = v
            if (kind == "a" && k == "plugin") { aplugin[a] = v; parent[a] = c; order[++na] = a }
            if (kind == "cfg" && k == "SystrayContainmentId") trayid[a] = v
        }
        END {
            for (i = 1; i <= na; i++) if (aplugin[order[i]] == "tidewater.status") ours[parent[order[i]]] = 1
            for (i = 1; i <= na; i++) {
                a = order[i]
                if (aplugin[a] != "org.kde.plasma.systemtray" || !(parent[a] in ours)) continue
                if (a in trayid) {
                    t = trayid[a]
                    if (cplugin[t] == "org.kde.plasma.private.systemtray") print "Containments " t " General"
                } else {
                    print "Containments " parent[a] " Applets " a " General"
                }
            }
        }
    ' "$RC" | sort -u
}
trays=$(find_trays)
if [ -z "$trays" ]; then
    say "No system tray found next to Tidewater's status widget, so there is nothing to tidy."
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
    for part in $tray; do groups+=(--group "$part"); done
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
