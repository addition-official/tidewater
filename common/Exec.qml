// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// Runs a shell command without blocking (Plasma's executable data engine).
import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: ds
    engine: "executable"
    connectedSources: []
    // cmd is always the command as it was passed to run() or start().
    signal finished(string cmd, string stdout, int code)

    // The engine keeps a finished source around for a moment and hands its old
    // result back to anyone who connects to the same name again. So every run
    // gets a name of its own: the command plus a numbered shell comment
    // (" #tw12"), which the shell ignores.
    property int seq: 0
    property var busy: ({})     // command -> how many runs of it are going
    property var again: ({})    // command -> true when one more run is wanted

    // run(cmd): skipped while the same command still runs (slow polls pile up
    // into one). run(cmd, true): a toggle asked for again while it still runs
    // (a quick double mute click) runs once more when the first has finished.
    // start(cmd): always runs at once (launching apps, opening files).
    function run(cmd, repeat, now) {
        if (now || !(busy[cmd] > 0))
            start(cmd);
        else if (repeat)
            again[cmd] = true;
    }
    function start(cmd) {
        busy[cmd] = (busy[cmd] || 0) + 1;
        connectSource(cmd + " #tw" + (++seq));
    }

    onNewData: (source, data) => {
        disconnectSource(source);
        const cut = source.lastIndexOf(" #tw");
        const cmd = cut >= 0 ? source.substring(0, cut) : source;
        if (busy[cmd] > 1)
            busy[cmd]--;
        else
            delete busy[cmd];
        const code = data["exit code"];
        if (code !== 0) {
            const err = String(data["stderr"] || "").trim().substring(0, 200);
            console.warn("tidewater:", label(cmd), "exited with", code + (err ? ": " + err : ""));
        }
        // start the wanted re-run first, so a handler that runs the same
        // command again is folded into it instead of running it twice
        if (again[cmd] && !(busy[cmd] > 0)) {
            delete again[cmd];
            start(cmd);
        }
        finished(cmd, data["stdout"], code);
    }

    // A short name for a command in the log: the program (or the script run by
    // bash or python3) and its subcommand, without paths or arguments that
    // could hold search text, user names or network names.
    function label(cmd) {
        const m = /^(?:bash|sh|python3)\s+('(?:[^']|'\\'')*'|\S+)\s*(.*)$/.exec(cmd);
        let name, rest;
        if (m) {
            name = m[1].replace(/'/g, "").split("/").pop();
            rest = m[2];
        } else {
            const i = cmd.search(/\s|$/);
            name = cmd.substring(0, i);
            rest = cmd.substring(i);
        }
        const sub = rest.split(/\s+/).filter(w => w.length > 0 && !w.startsWith("-"))[0];
        return sub && /^[A-Za-z][\w.-]*$/.test(sub) ? name + " " + sub : name;
    }

    // Single-quote an argument for the shell.
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
}
