// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Runs a shell command without blocking (Plasma's executable data engine).
import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: ds
    engine: "executable"
    connectedSources: []
    signal finished(string cmd, string stdout, int code)
    // The engine can't run the same command twice at once. A toggle asked for
    // again while it still runs (a quick double mute click) must really run
    // twice, so run(cmd, true) remembers it and runs it once the first has
    // fully gone. Everything else (polls) is simply skipped while running.
    property var again: ({})
    onNewData: (source, data) => {
        disconnectSource(source);
        if (data["exit code"] !== 0)
            console.warn("tidewater:", source, "->", data["stderr"]);
        finished(source, data["stdout"], data["exit code"]);
    }
    // Only when the engine has dropped the finished source can it run anew;
    // connecting before that just replays the old result.
    onSourceRemoved: source => {
        if (again[source] > 0) {
            delete again[source];
            connectSource(source);
        }
    }
    function run(cmd, repeat) {
        if (connectedSources.indexOf(cmd) < 0)
            connectSource(cmd);
        else if (repeat)
            again[cmd] = 1;
    }
    // Single-quote an argument for the shell.
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
}
