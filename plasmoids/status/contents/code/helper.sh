#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 addition-official
#
# Tidewater helper. The widget never touches the system itself: every read
# and every switch goes through this one script, so you can read exactly what
# it does, and debug it from a terminal:
#
#   bash helper.sh status          # prints the JSON the widget draws from
#   bash helper.sh wifi off        # any command below works by hand too
#
# Nothing here uses sudo, the network, or any file outside your own config.

set -u
have() { command -v "$1" >/dev/null 2>&1; }

# JSON string, escaped.
js() {
    local s=${1//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/ }
    s=${s//$'\n'/ }
    s=${s//[[:cntrl:]]/}          # any other control char would break JSON.parse
    printf '"%s"' "$s"
}
# Whole non-negative number? (Checked before any $(( )): bash evaluates
# array subscripts in arithmetic, so untrusted text there can run commands.)
isnum() { [[ ${1-} =~ ^[0-9]+$ ]]; }
jb() { [ "$1" = 1 ] && printf true || printf false; }

prop() { busctl --user get-property "$@" 2>/dev/null; }

PD=org.kde.Solid.PowerManagement
SB=/org/kde/ScreenBrightness

first_display() {
    prop "$PD" "$SB" org.kde.ScreenBrightness DisplaysDBusNames \
        | grep -o '"[A-Za-z0-9_]*"' | head -1 | tr -d '"'
}

status() {
    local user full host up avatar
    user=$(id -un)
    full=$(getent passwd "$user" | cut -d: -f5 | cut -d, -f1)
    [ -n "$full" ] || full=$user
    host=$(uname -n)
    up=$(cut -d. -f1 /proc/uptime)
    avatar=""
    for f in "$HOME/.face.icon" "$HOME/.face" "/var/lib/AccountsService/icons/$user"; do
        [ -r "$f" ] && { avatar=$f; break; }
    done

    # Network (NetworkManager)
    local wifi_hw=0 wifi_on=0 wifi_blocked=0 ssid="" eth_hw=0 eth_on=0 eth_speed="" signal=0
    if have nmcli; then
        [ "$(nmcli -t -f WIFI radio 2>/dev/null)" = enabled ] && wifi_on=1
        while IFS=: read -r type state dev conn; do
            # nmcli -t escapes ":" as "\:" and "\" as "\\"
            conn=${conn//\\\\/$'\001'}
            conn=${conn//\\:/:}
            conn=${conn//$'\001'/\\}
            case $type in
                wifi)
                    wifi_hw=1
                    [[ $state == connected* ]] && ssid=$conn ;;
                ethernet)
                    eth_hw=1
                    if [[ $state == connected* ]] && [ "$eth_on" = 0 ]; then
                        eth_on=1
                        local sp
                        sp=$(cat "/sys/class/net/$dev/speed" 2>/dev/null || echo -1)
                        if [ "${sp:-0}" -ge 1000 ] 2>/dev/null; then
                            eth_speed=$(awk -v s="$sp" 'BEGIN{printf "%g Gbit/s", s/1000}')
                        elif [ "${sp:-0}" -gt 0 ] 2>/dev/null; then
                            eth_speed="$sp Mbit/s"
                        fi
                    fi ;;
            esac
        done < <(nmcli -t -f TYPE,STATE,DEVICE,CONNECTION device 2>/dev/null)
        [ -n "$ssid" ] && signal=$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')
    fi

    # The kernel knows about Wi-Fi hardware even while it's switched off, when
    # some drivers drop out of NetworkManager's device list. Look there too.
    for phy in /sys/class/ieee80211/*; do [ -e "$phy" ] && wifi_hw=1 && break; done
    local rf soft=0 hard=0
    for rf in /sys/class/rfkill/rfkill*; do
        [ "$(cat "$rf/type" 2>/dev/null)" = wlan ] || continue
        wifi_hw=1
        [ "$(cat "$rf/soft" 2>/dev/null)" = 1 ] && soft=1
        [ "$(cat "$rf/hard" 2>/dev/null)" = 1 ] && hard=1
    done
    [ "$soft" = 1 ] && wifi_on=0
    [ "$hard" = 1 ] && { wifi_on=0; wifi_blocked=1; }

    # Bluetooth (BlueZ)
    local bt_hw=0 bt_on=0 bt_n=0 bt_ok=0 show
    if have bluetoothctl; then
        show=$(timeout 2 bluetoothctl show 2>/dev/null)
        if grep -q '^Controller' <<<"$show"; then
            bt_hw=1
            bt_ok=1
            grep -q 'Powered: yes' <<<"$show" && bt_on=1
            bt_n=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -c '^Device')
        fi
    fi

    # The kernel lists Bluetooth adapters even when they're switched off or
    # bluetoothd isn't answering.
    local hci
    for hci in /sys/class/bluetooth/hci*; do [ -e "$hci" ] && bt_hw=1 && break; done
    for rf in /sys/class/rfkill/rfkill*; do
        [ "$(cat "$rf/type" 2>/dev/null)" = bluetooth ] && bt_hw=1
    done

    # Audio (PipeWire)
    local vol=-1 muted=0 mic_hw=0 mic_on=0 mic_name="" v
    if have wpctl; then
        v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [ -n "$v" ]; then
            vol=$(awk '{printf "%d", $2*100+0.5}' <<<"$v")
            [[ $v == *MUTED* ]] && muted=1
        fi
        v=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
        if [ -n "$v" ]; then
            mic_hw=1
            [[ $v == *MUTED* ]] || mic_on=1
            mic_name=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
                | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -1)
        fi
    fi

    # Brightness (powerdevil), laptop panels and DDC monitors alike
    local bri=-1 d cur max
    d=$(first_display)
    if [ -n "$d" ]; then
        cur=$(prop "$PD" "$SB/$d" org.kde.ScreenBrightness.Display Brightness | awk '{print $2}')
        max=$(prop "$PD" "$SB/$d" org.kde.ScreenBrightness.Display MaxBrightness | awk '{print $2}')
        isnum "$cur" && isnum "$max" && [ "$max" -gt 0 ] && bri=$(( (cur * 100 + max / 2) / max ))
    fi

    # Night Light (KWin)
    local nl_hw=0 nl_on=0 nl_inh=0 nl_run=0
    [ "$(prop org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight available)" = "b true" ] && nl_hw=1
    [ "$(prop org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight enabled)" = "b true" ] && nl_on=1
    [ "$(prop org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight inhibited)" = "b true" ] && nl_inh=1
    [ "$(prop org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight running)" = "b true" ] && nl_run=1

    # Do not disturb (the same key Plasma's own notification applet writes)
    local dnd=0 until
    until=$(kreadconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until 2>/dev/null)
    if [ -n "$until" ]; then
        local y mo dd h mi s
        IFS=, read -r y mo dd h mi s <<<"$until"
        if [ -n "$y" ] && [ "$(date -d "$y-$mo-$dd ${h:-0}:${mi:-0}:${s:-0}" +%s 2>/dev/null || echo 0)" -gt "$(date +%s)" ]; then
            dnd=1
        fi
    fi

    printf '{'
    printf '"user":%s,"fullName":%s,"host":%s,"uptime":%s,"avatar":%s,' \
        "$(js "$user")" "$(js "$full")" "$(js "$host")" "${up:-0}" "$(js "$avatar")"
    printf '"wifiHw":%s,"wifiOn":%s,"ssid":%s,"signal":%s,"wifiBlocked":%s,' "$(jb $wifi_hw)" "$(jb $wifi_on)" "$(js "$ssid")" "${signal:-0}" "$(jb $wifi_blocked)"
    printf '"ethHw":%s,"ethOn":%s,"ethSpeed":%s,' "$(jb $eth_hw)" "$(jb $eth_on)" "$(js "$eth_speed")"
    printf '"btHw":%s,"btOn":%s,"btConnected":%s,"btOk":%s,' "$(jb $bt_hw)" "$(jb $bt_on)" "${bt_n:-0}" "$(jb $bt_ok)"
    printf '"vol":%s,"muted":%s,"micHw":%s,"micOn":%s,"micName":%s,' \
        "$vol" "$(jb $muted)" "$(jb $mic_hw)" "$(jb $mic_on)" "$(js "$mic_name")"
    printf '"bri":%s,' "$bri"
    printf '"nlHw":%s,"nlOn":%s,"nlInhibited":%s,"nlRunning":%s,' \
        "$(jb $nl_hw)" "$(jb $nl_on)" "$(jb $nl_inh)" "$(jb $nl_run)"
    printf '"dnd":%s' "$(jb $dnd)"
    printf '}\n'
}

cmd=${1:-status}
shift || true
case $cmd in
    status) status ;;
    wifi)                                                 # on | off
        if [ "$1" = on ]; then
            # clear a soft block too (Plasma's airplane mode / Wi-Fi switch sets one)
            rfkill unblock wlan 2>/dev/null || true
            nmcli radio wifi on
        else
            nmcli radio wifi off
        fi ;;
    bluetooth)
        if [ "$1" = on ]; then
            rfkill unblock bluetooth 2>/dev/null
            timeout 4 bluetoothctl power on
        else
            timeout 4 bluetoothctl power off
        fi ;;
    mic) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    volume)                                               # 0-100
        isnum "${1-}" || exit 2
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1%"
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 ;;
    brightness)                                           # 0-100
        d=$(first_display)
        [ -n "$d" ] || exit 1
        max=$(prop "$PD" "$SB/$d" org.kde.ScreenBrightness.Display MaxBrightness | awk '{print $2}')
        isnum "${1-}" && isnum "$max" || exit 2
        # flag 1 = don't flash Plasma's OSD while dragging our own slider
        busctl --user call "$PD" "$SB/$d" org.kde.ScreenBrightness.Display \
            SetBrightness iu $(( $1 * max / 100 )) 1 ;;
    nightlight)
        busctl --user call org.kde.kglobalaccel /component/kwin \
            org.kde.kglobalaccel.Component invokeShortcut s "Toggle Night Color" ;;
    dnd)                                                  # on | off
        if [ "$1" = on ]; then
            kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until --notify "2099,12,31,23,59,59"
        else
            kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until --notify --delete
        fi ;;
    watch-audio)
        # Returns as soon as anything changes the sound (volume keys, other
        # apps, a new default device), so the widget can update at once.
        # Exit 3 = pactl isn't available; the widget then polls instead.
        command -v pactl >/dev/null 2>&1 || exit 3
        # In its own process group, so "kill 0" only ends this little pipeline,
        # and timeout inside it, so on timeout the whole group (pactl too) goes.
        # Prints "hit" when a real change arrived (vs. a timeout or failure).
        # "sink #" / "server" only: not sink-input, i.e. not apps opening streams.
        setsid -w timeout 120 bash -c \
            'pactl subscribe 2>/dev/null | { grep -m1 -qE "on (sink #|server)" && echo hit; kill 0; }' \
            2>/dev/null
        exit 0 ;;
    open) setsid -f "$@" >/dev/null 2>&1 ;;               # launch a settings page
    power) busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptAll ;;
    lock) loginctl lock-session ;;
    *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
