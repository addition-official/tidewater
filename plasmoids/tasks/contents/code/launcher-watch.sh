#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Taskbar badges: waits for the messages apps send about their taskbar icon
# (unread counts, progress of a download or copy; the "Unity launcher" D-Bus
# signal that Chrome, Firefox, Thunderbird, Discord, Telegram, Dolphin and
# others send) and prints them, one JSON line per message, then exits.
#
# The taskbar runs it again as soon as it exits, so it keeps listening.
# Messages that arrive within a moment of the first are printed together,
# which keeps the gap between runs short. With no message for about 25
# seconds it prints nothing and exits, so it never hangs around for long.
set -u
M="type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'"

# Read from busctl through a process substitution, not a pipe: the shell does
# not wait for it, so this returns the moment the messages are printed
# (a pipe would wait for busctl's own timeout).
exec 3< <(exec timeout 25 stdbuf -oL busctl --user monitor --json=short --match "$M" 2>/dev/null)
pid=$!

# The first message: wait up to busctl's own timeout. After it, collect what
# follows for at most half a second (an app sending progress many times a
# second must not keep this from returning).
wait_for=26
deadline=""
while IFS= read -r -t "$wait_for" line <&3; do
    case $line in
        *'"member":"Update"'*)
            printf '%s\n' "$line"
            [ -n "$deadline" ] || deadline=$(( ${EPOCHREALTIME/./} + 500000 ))
            wait_for=0.2 ;;
    esac
    [ -n "$deadline" ] && [ "${EPOCHREALTIME/./}" -ge "$deadline" ] && break
done
kill "$pid" 2>/dev/null
exit 0
