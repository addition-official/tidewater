#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Tidewater start menu helper. The menu never touches the system itself:
# every read and every launch goes through this one script. Everything is
# local: .desktop files, your recent-files list, /proc and /sys, and MPRIS
# over the session bus. Nothing uses the network or sudo. Try it by hand:
#
#   python3 menu.py apps | recent | stats | media | files <query>
#   python3 menu.py launch <desktop-id> | open <url> | media-cmd PlayPause
#   python3 menu.py taskbar-pins | taskbar-pin <desktop-id> | taskbar-unpin <desktop-id>

import glob
import json
import locale
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")


def out(obj):
    sys.stdout.write(json.dumps(obj))
    sys.stdout.write("\n")


def run(cmd, timeout=3):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


# ---- applications --------------------------------------------------------------

def data_dirs():
    dirs = [os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")]
    dirs += (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    for extra in ("/var/lib/flatpak/exports/share", os.path.join(HOME, ".local/share/flatpak/exports/share"),
                  "/var/lib/snapd/desktop"):
        if extra not in dirs:
            dirs.append(extra)
    return dirs


def read_desktop(path):
    """The [Desktop Entry] keys, plus each [Desktop Action X] under entry["_actions"][X]."""
    entry, section, actions = {}, None, {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    section = line
                    continue
                if "=" not in line or line.startswith("#"):
                    continue
                k, v = line.split("=", 1)
                if section == "[Desktop Entry]":
                    entry[k.strip()] = v.strip()
                elif section and section.startswith("[Desktop Action ") and section.endswith("]"):
                    actions.setdefault(section[len("[Desktop Action "):-1], {})[k.strip()] = v.strip()
    except OSError:
        return None
    entry["_actions"] = actions
    return entry


def app_actions(e):
    """The app's own extra actions ("New private window", ...), in its order."""
    out = []
    for aid in filter(None, (x.strip() for x in e.get("Actions", "").split(";"))):
        a = e["_actions"].get(aid)
        if a and a.get("Exec") and localized(a, "Name"):
            out.append({"id": aid, "name": localized(a, "Name"), "icon": a.get("Icon", "")})
    return out


def exec_args(line, entry, path):
    """Split a desktop-file Exec line into argv, as the Desktop Entry spec says:
    double-quoted args with \\ escapes; field codes dropped (no files are
    passed), except %i (icon), %c (name) and %k (file); %% is a literal %."""
    # first the general string escapes of desktop files (\\s \\n \\t \\r \\\\) ...
    line = re.sub(r"\\(.)", lambda m: {"s": " ", "n": "\n", "t": "\t", "r": "\r"}.get(m.group(1), "\\" + m.group(1))
                  if m.group(1) != "\\" else "\\", line)
    # ... then the Exec quoting rules
    args, cur, i, quoted, started = [], "", 0, False, False
    while i < len(line):
        c = line[i]
        if quoted:
            if c == "\\" and i + 1 < len(line):
                cur += line[i + 1]; i += 2; continue
            if c == '"':
                quoted = False
            else:
                cur += c
        elif c == '"':
            quoted = started = True
        elif c in " \t":
            if started:
                args.append(cur); cur, started = "", False
        else:
            cur += c; started = True
        i += 1
    if started:
        args.append(cur)
    out = []
    for a in args:
        if a == "%i":
            if entry.get("Icon"):
                out += ["--icon", entry["Icon"]]
            continue
        if a in ("%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%v", "%m"):
            continue
        a = re.sub(r"%[fFuUdDnNvm]", "", a)            # codes inside an argument
        a = a.replace("%c", localized(entry, "Name")).replace("%k", path or "")
        a = a.replace("%%", "%")
        out.append(a)
    return out


def launch_action(did, aid):
    """Run one of the app's own actions (e.g. Opera's "New private window")."""
    path = desktop_path(did)
    e = read_desktop(path) if path else None
    a = e and e["_actions"].get(aid)
    if not a or not a.get("Exec"):
        return
    # %i / %c / %k refer to the app itself (its Icon, Name and file)
    args = exec_args(a["Exec"], e, path)
    if args and shutil.which(args[0]):
        subprocess.Popen(args, start_new_session=True, cwd=e.get("Path") or HOME,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def localized(entry, key):
    lang = (locale.getlocale()[0] or os.environ.get("LANG", "")).split(".")[0]
    for k in (f"{key}[{lang}]", f"{key}[{lang.split('_')[0]}]", key):
        if entry.get(k):
            return entry[k]
    return ""


def apps():
    seen, result = set(), []
    desktop = set(filter(None, (os.environ.get("XDG_CURRENT_DESKTOP") or "KDE").split(":")))
    for d in data_dirs():
        base = os.path.join(d, "applications")
        for path in sorted(glob.glob(os.path.join(base, "**", "*.desktop"), recursive=True)):
            did = os.path.relpath(path, base).replace("/", "-")
            if did in seen:
                continue
            seen.add(did)  # the first one found wins, as the spec says
            e = read_desktop(path)
            if not e or e.get("Type") != "Application":
                continue
            if e.get("NoDisplay") == "true" or e.get("Hidden") == "true":
                continue
            only = set(filter(None, e.get("OnlyShowIn", "").split(";")))
            notin = set(filter(None, e.get("NotShowIn", "").split(";")))
            if (only and not only & desktop) or notin & desktop:
                continue
            name = localized(e, "Name")
            if not name:
                continue
            result.append({
                "id": did,
                "name": name,
                "generic": localized(e, "GenericName"),
                "comment": localized(e, "Comment"),
                "icon": e.get("Icon", "application-x-executable"),
                "categories": e.get("Categories", ""),
                "keywords": localized(e, "Keywords"),
                "actions": app_actions(e),
                "path": path,
            })
    result.sort(key=lambda a: a["name"].lower())
    return result


def desktop_path(did):
    """Where the .desktop file for an app id lives (first match wins, as in the spec)."""
    for d in data_dirs():
        base = os.path.join(d, "applications")
        path = os.path.join(base, did)
        if os.path.isfile(path):
            return path
        # ids with dashes can live in subfolders: kde-foo.desktop -> kde/foo.desktop
        parts = did.split("-")
        for i in range(1, len(parts)):
            path = os.path.join(base, "/".join(parts[:i]), "-".join(parts[i:]))
            if os.path.isfile(path):
                return path
    return None


def try_run(cmd):
    """Start cmd detached; True if it started and didn't fail straight away."""
    if not shutil.which(cmd[0]):
        return False
    try:
        proc = subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        return False
    try:
        return proc.wait(timeout=3) == 0      # launchers hand off and exit quickly
    except subprocess.TimeoutExpired:
        return True                           # still running: it's the app itself


def launch(did):
    """Start a new copy of an app, every time, the way Plasma's own menu does."""
    path = desktop_path(did)
    if path and try_run(["kioclient", "exec", path]):   # KDE's app launcher (same as Kickoff)
        return
    if try_run(["gtk-launch", did]):
        return
    if path and try_run(["gio", "launch", path]):
        return
    # Last resort: run the Exec line ourselves, read by the desktop-file rules
    # (quoting, escapes, %f/%u dropped, %i/%c/%k filled in), as app actions are.
    e = read_desktop(path) if path else None
    if e and e.get("Exec"):
        args = exec_args(e["Exec"], e, path)
        if args and shutil.which(args[0]):
            subprocess.Popen(args, start_new_session=True, cwd=e.get("Path") or HOME,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_url(url):
    tool = "kde-open" if shutil.which("kde-open") else "xdg-open"
    subprocess.Popen([tool, url], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ---- recent files (KDE writes these to recently-used.xbel) ----------------------

def pretty_dir(path):
    d = os.path.dirname(path)
    return "~" + d[len(HOME):] if d.startswith(HOME) else d


def recent(limit=20):
    xbel = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share"), "recently-used.xbel")
    items = []
    try:
        root = ET.parse(xbel).getroot()
    except Exception:
        return []
    for b in root.iter("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"):
            continue
        path = urllib.parse.unquote(href[7:])
        if not os.path.exists(path):
            continue
        items.append({
            "name": os.path.basename(path.rstrip("/")) or path,
            "dir": pretty_dir(path),
            "url": href,
            "folder": os.path.isdir(path),
            "when": b.get("modified") or b.get("visited") or b.get("added") or "",
        })
    items.sort(key=lambda i: i["when"], reverse=True)
    return items[:limit]


def files(query, limit=6):
    if not query or not shutil.which("baloosearch6"):
        return []
    res = []
    for path in run(["baloosearch6", "-l", str(limit), "--", query]).splitlines():
        path = path.strip()
        if path and os.path.exists(path):
            res.append({"name": os.path.basename(path), "dir": pretty_dir(path),
                        "url": "file://" + urllib.parse.quote(path), "folder": os.path.isdir(path)})
    return res


# ---- system stats ---------------------------------------------------------------

def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def cpu_fraction():
    parts = read("/proc/stat").splitlines()[0].split()[1:]
    vals = [int(x) for x in parts]
    idle, total = vals[3] + vals[4], sum(vals)
    # Our own private dir (never a shared /tmp name another user could plant).
    base = os.environ.get("XDG_RUNTIME_DIR") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "tidewater")
    os.makedirs(base, mode=0o700, exist_ok=True)
    state = os.path.join(base, "tidewater-cpu")
    prev = read(state).split()
    try:
        fd = os.open(state, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(f"{idle} {total}")
    except OSError:
        pass
    try:
        di, dt = idle - int(prev[0]), total - int(prev[1])
        if dt > 0:
            return max(0.0, min(1.0, 1 - di / dt))
    except (ValueError, IndexError):
        pass
    return 0.0


def hwmon_temp(names):
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(os.path.join(h, "name")) in names:
            t = read(os.path.join(h, "temp1_input"))
            if t.isdigit():
                return round(int(t) / 1000)
    return 0


def stats():
    mem = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":", 1)
        mem[k] = int(v.split()[0]) * 1024
    total = mem.get("MemTotal", 0)
    used = total - mem.get("MemAvailable", 0)
    du = shutil.disk_usage(HOME)

    gpu, gpu_temp = -1.0, 0
    for busy in glob.glob("/sys/class/drm/card*/device/gpu_busy_percent"):
        v = read(busy)
        if v.isdigit():
            gpu = int(v) / 100
            gpu_temp = hwmon_temp({"amdgpu"})
            break
    if gpu < 0 and shutil.which("nvidia-smi"):
        line = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"])
        try:
            u, t = [x.strip() for x in line.splitlines()[0].split(",")]
            gpu, gpu_temp = int(u) / 100, int(t)
        except Exception:
            pass

    import pwd
    user = pwd.getpwuid(os.getuid())
    avatar = next((f for f in (os.path.join(HOME, ".face.icon"), os.path.join(HOME, ".face"),
                                "/var/lib/AccountsService/icons/" + user.pw_name) if os.access(f, os.R_OK)), "")
    return {
        "user": user.pw_name,
        "fullName": (user.pw_gecos or "").split(",")[0] or user.pw_name,
        "uptime": int(float(read("/proc/uptime", "0").split()[0])),
        "avatar": avatar,
        "cpu": cpu_fraction(),
        "cpuTemp": hwmon_temp({"k10temp", "coretemp", "zenpower", "cpu_thermal"}),
        "memUsed": used, "memTotal": total,
        "diskFree": du.free, "diskSize": du.total,
        "gpu": gpu, "gpuTemp": gpu_temp,
    }


# ---- media (MPRIS over the session bus) -------------------------------------------

def busctl_json(args):
    try:
        return json.loads(run(["busctl", "--user", "--json=short"] + args) or "null")
    except Exception:
        return None


def players():
    names = busctl_json(["call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                         "org.freedesktop.DBus", "ListNames"])
    if not names:
        return []
    return [n for n in names["data"][0] if n.startswith("org.mpris.MediaPlayer2.")]


def media():
    best = None
    for p in players():
        props = busctl_json(["call", p, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
                             "GetAll", "s", "org.mpris.MediaPlayer2.Player"])
        if not props:
            continue
        d = props["data"][0]
        status = d.get("PlaybackStatus", {}).get("data", "Stopped")
        meta = d.get("Metadata", {}).get("data", {})
        get = lambda k: (meta.get(k) or {}).get("data")
        artist = get("xesam:artist") or []
        info = {
            "player": p,
            "title": get("xesam:title") or "",
            "artist": ", ".join(artist) if isinstance(artist, list) else str(artist),
            "art": get("mpris:artUrl") or "",
            "playing": status == "Playing",
        }
        if not info["title"]:
            continue
        if best is None or (info["playing"] and not best["playing"]):
            best = info
    return best or {}


def media_cmd(method):
    m = media()
    if m.get("player") and method in ("PlayPause", "Next", "Previous"):
        run(["busctl", "--user", "call", m["player"], "/org/mpris/MediaPlayer2",
             "org.mpris.MediaPlayer2.Player", method])


# ---- taskbar pins (the Tidewater taskbar's pinned apps) -------------------------
# The taskbar keeps its pins in its own settings; a Plasma desktop script is the
# supported way for one widget to change another's, and the taskbar picks the
# change up at once.

TASKS = "tidewater.tasks"


def plasma_script(js):
    res = busctl_json(["call", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", "s", js])
    return (res or {}).get("data", [""])[0] if isinstance(res, dict) else ""


def taskbar_pins():
    out = plasma_script("""
        var pins = [];
        panels().forEach(function (p) {
            p.widgets("%s").forEach(function (w) {
                w.currentConfigGroup = ["General"];
                var l = w.readConfig("launchers", "");
                pins = pins.concat(typeof l === "string" ? l.split(",") : l);
            });
        });
        print(JSON.stringify(pins));
    """ % TASKS)
    try:
        pins = json.loads(out.strip().splitlines()[-1]) if out.strip() else []
    except Exception:
        pins = []
    return sorted({p[len("applications:"):] for p in pins if p.startswith("applications:")})


def taskbar_pin(did, pin):
    url = "applications:" + did
    plasma_script("""
        var url = %s, pin = %s;
        panels().forEach(function (p) {
            p.widgets("%s").forEach(function (w) {
                w.currentConfigGroup = ["General"];
                var l = w.readConfig("launchers", "");
                l = (typeof l === "string" ? l.split(",") : l).filter(function (x) { return x && x !== url; });
                if (pin) l.push(url);
                w.writeConfig("launchers", l);
            });
        });
    """ % (json.dumps(url), "true" if pin else "false", TASKS))


# ---- session ------------------------------------------------------------------

def session(what):
    cmds = {
        "lock": ["loginctl", "lock-session"],
        "sleep": ["systemctl", "suspend"],
        "logout": ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptLogout"],
        "restart": ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptReboot"],
        "shutdown": ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptShutDown"],
        "power": ["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptAll"],
        "settings": ["systemsettings"],
    }
    if what in cmds:
        subprocess.Popen(cmds[what], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    arg = " ".join(sys.argv[2:])
    if cmd == "apps":
        out(apps())
    elif cmd == "recent":
        out(recent())
    elif cmd == "files":
        out(files(arg))
    elif cmd == "stats":
        out(stats())
    elif cmd == "media":
        out(media())
    elif cmd == "media-cmd":
        media_cmd(arg)
    elif cmd == "launch":
        launch(arg)
    elif cmd == "action" and len(sys.argv) == 4:
        launch_action(sys.argv[2], sys.argv[3])
    elif cmd == "open":
        open_url(arg)
    elif cmd == "taskbar-pins":
        out(taskbar_pins())
    elif cmd == "taskbar-pin":
        taskbar_pin(arg, True)
    elif cmd == "taskbar-unpin":
        taskbar_pin(arg, False)
    elif cmd == "session":
        session(arg)
    else:
        sys.stderr.write("usage: menu.py apps|recent|files Q|stats|media|media-cmd M|launch ID|action ID ACTION|open URL|session WHAT\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
