#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Restart Plasma's shell (panels, widgets, desktop) so it loads new code and
# settings. Works however Plasma was started: through systemd or not.
#
#   ./restart-plasma.sh          restart
#   ./restart-plasma.sh stop     stop only (used by tidy-tray.sh and uninstall.sh)
#   ./restart-plasma.sh start    start only

set -u
die() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" != 0 ] || die "Run this as your normal user, not with sudo."

running() { pgrep -u "$(id -u)" -x plasmashell >/dev/null; }

stop_plasma() {
    running || return 0
    if systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
        systemctl --user stop plasma-plasmashell.service 2>/dev/null
    fi
    running && { kquitapp6 plasmashell >/dev/null 2>&1 || true; }
    for _ in $(seq 1 40); do running || return 0; sleep 0.25; done
    # still there after 10 seconds: ask it to quit the plain way
    pkill -u "$(id -u)" -x plasmashell 2>/dev/null
    for _ in $(seq 1 20); do running || return 0; sleep 0.25; done
    return 1
}

start_plasma() {
    running && return 0
    # kstart is what reliably brings Plasma back, however it was started before.
    if command -v kstart >/dev/null 2>&1; then
        setsid kstart plasmashell >/dev/null 2>&1 &
    elif systemctl --user cat plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user start plasma-plasmashell.service 2>/dev/null
    else
        setsid plasmashell >/dev/null 2>&1 &
    fi
    for _ in $(seq 1 40); do running && return 0; sleep 0.25; done
    return 1
}

case "${1:-restart}" in
    stop) stop_plasma ;;
    start) start_plasma ;;
    # if Plasma won't stop, starting it again would do nothing: say so
    *) stop_plasma || die "Plasma didn't stop, so it wasn't restarted."; start_plasma ;;
esac
