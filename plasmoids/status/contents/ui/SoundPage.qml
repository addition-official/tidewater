// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 addition-official
// The quick settings' "Sound output" page, in the manner of Windows 11: the
// output devices (the current one marked; click one to switch to it), then a
// volume mixer (the output device, and each app that is playing sound), and
// "More volume settings" at the bottom for System Settings' sound page.
// Scrolls when there is more than fits.
//
// Live from Plasma's own volume module (plasma-pa), the same one Plasma's
// volume applet uses, and filtered the same way it does (applet/main.qml).
// main.qml loads this file with a Loader, so a Plasma without the module only
// loses this page.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume
import "common"
// ~/.local/share/tidewater/qml: the installed apps (the start menu's list)
import "../../../../../tidewater/qml"

Item {
    id: page
    required property var pal
    signal back()
    signal more()
    // the page's height: everything, up to a limit, then it scrolls
    readonly property int maxListHeight: 440
    implicitHeight: header.height + Math.min(list.implicitHeight, maxListHeight) + footer.height

    // ---- Plasma's volume module, filtered like its own applet ----
    SinkModel { id: sinkModel }
    SinkInputModel { id: streamModel }
    PulseObjectFilterModel {
        id: sinks
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: sinkModel
    }
    PulseObjectFilterModel {
        id: streams
        filters: [
            { role: "VirtualStream", value: false },
            // event sounds (notifications, clicks) are not an app playing
            { role: "Client", value: c => !c || c.name !== "libcanberra" }
        ]
        sourceModel: streamModel
    }

    function percentOf(raw) { return Math.round(raw / PulseAudio.NormalVolume * 100); }
    function rawOf(pct) { return Math.round(PulseAudio.NormalVolume * Math.max(0, Math.min(100, pct)) / 100); }
    function deviceName(m) {
        const port = m.Ports && m.ActivePortIndex >= 0 ? m.Ports[m.ActivePortIndex] : null;
        const base = m.Description || m.Name || "Output device";
        // one device: its port says more ("Headphones"); several: their names
        return sinks.count > 1 ? base : (port && port.description ? port.description + " (" + base + ")" : base);
    }
    // devices get a plain line drawing, like Windows: headphones or a speaker
    function deviceGlyph(m) {
        const ff = String(m.FormFactor || "");
        const port = m.Ports && m.ActivePortIndex >= 0 ? m.Ports[m.ActivePortIndex] : null;
        const portName = port ? String(port.name || "") + String(port.description || "") : "";
        return ff === "headphone" || ff === "headset" || /headphone|headset/i.test(portName) ? "headphones" : "speaker";
    }
    // The installed app a sound stream belongs to, from the start menu's
    // list, so it shows with its real icon and name. Plasma's own guess at
    // the icon tries the program's name as an icon name, which can be a
    // different icon altogether (Zoom's program "zoom" is the theme's
    // magnifying glass).
    readonly property var installedApps: {
        const o = Settings.searchOwner(-1);
        return o && o.apps ? o.apps : [];
    }
    function lastPart(id) { const p = String(id).split("."); return p[p.length - 1]; }
    function appFor(m) {
        const props = m.Properties || {};
        const c = m.Client;
        const keys = [props["pipewire.access.portal.app_id"], props["application.id"],
                      props["application.process.binary"], props["application.name"],
                      c && c.name, m.Name]
            .filter(k => !!k).map(k => String(k).toLowerCase());
        for (const k of keys)
            for (const a of installedApps) {
                const id = String(a.id || "").replace(/\.desktop$/, "").toLowerCase();
                const bin = String(a.bin || "").toLowerCase();
                const names = [id, lastPart(id), bin, lastPart(bin),
                               String(a.wmclass || "").toLowerCase(), String(a.name || "").toLowerCase()];
                if (names.indexOf(k) >= 0 || names.indexOf(lastPart(k)) >= 0)
                    return a;
            }
        return null;
    }
    function appName(m) {
        const a = appFor(m);
        if (a) return a.name;
        const c = m.Client;
        if (c && c.name && c.name !== "pipewire-media-session") return c.name;
        return m.Name || "App";
    }
    function appIcon(m) {
        const a = appFor(m);
        return (a && a.icon) || m.IconName || "audio-volume-high";
    }

    component Heading: Text {
        Layout.leftMargin: 4
        Layout.topMargin: 14
        Layout.bottomMargin: 6
        font.family: page.pal.font
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: page.pal.text1
    }

    // ---- header: back, and the title ----
    Item {
        id: header
        width: parent.width
        height: 60
        Rectangle {
            id: backButton
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            radius: 6
            color: backArea.containsMouse ? page.pal.tintHover : "transparent"
            Glyph {
                anchors.centerIn: parent
                name: "arrow_back"; fallback: "go-previous"
                size: 20; wght: 300
                color: page.pal.text1
                fontAvailable: page.pal.hasIconFont
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.back()
            }
        }
        Text {
            anchors.left: backButton.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Sound output"
            font.family: page.pal.font
            font.pixelSize: 16
            color: page.pal.text1
        }
    }

    // ---- the list: devices, then the mixer ----
    Flickable {
        id: flick
        y: header.height
        width: parent.width
        height: Math.min(list.implicitHeight, page.maxListHeight)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: ThinScrollBar { tint: page.pal.text2 }

        ColumnLayout {
            id: list
            x: 16
            width: flick.width - 32
            spacing: 2

            Heading { text: "Output device"; Layout.topMargin: 0 }
            Repeater {
                model: sinks
                Rectangle {
                    id: dev
                    required property var model
                    readonly property bool current: !!model.Default
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 6
                    color: current ? page.pal.tintHover : devArea.containsMouse ? page.pal.tint : "transparent"
                    Rectangle {
                        visible: dev.current
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 18; radius: 1.5
                        color: page.pal.blue
                    }
                    Glyph {
                        id: devIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        name: page.deviceGlyph(dev.model); fallback: "audio-speakers-symbolic"
                        size: 20; wght: 300
                        color: page.pal.text1
                        fontAvailable: page.pal.hasIconFont
                    }
                    Text {
                        anchors.left: devIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.deviceName(dev.model)
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: page.pal.font
                        font.pixelSize: 13
                        color: page.pal.text1
                    }
                    MouseArea {
                        id: devArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!dev.current) dev.model.Default = true
                    }
                }
            }
            Text {
                visible: sinks.count === 0
                Layout.leftMargin: 4
                text: "No output devices"
                font.family: page.pal.font
                font.pixelSize: 13
                color: page.pal.text2
            }

            Heading { text: "Volume mixer" }
            // the output device (the current one), then each app
            Repeater {
                model: sinks
                MixerRow {
                    required property var model
                    visible: !!model.Default
                    entry: model
                    glyph: page.deviceGlyph(model)
                    label: page.deviceName(model)
                }
            }
            Repeater {
                model: streams
                MixerRow {
                    required property var model
                    entry: model
                    icon: page.appIcon(model)
                    label: page.appName(model)
                }
            }
            Text {
                visible: streams.count === 0
                Layout.leftMargin: 4
                Layout.topMargin: 4
                text: "No apps are playing sound"
                font.family: page.pal.font
                font.pixelSize: 12
                color: page.pal.text2
            }
            Item { implicitHeight: 12 }
        }
    }

    // a row of the mixer: the icon (click to mute; a small mark while muted)
    // and the slider
    component MixerRow: RowLayout {
        id: mr
        property var entry
        property string icon      // an app's icon
        property string glyph     // or a drawing (the output device)
        property string label
        readonly property int pct: entry ? page.percentOf(entry.Volume) : 0
        onPctChanged: slider.set(pct)
        Component.onCompleted: slider.set(pct)
        Layout.fillWidth: true
        implicitHeight: 48
        spacing: 8
        Rectangle {
            implicitWidth: 40; implicitHeight: 40
            radius: 6
            color: muteArea.containsMouse ? page.pal.tintHover : "transparent"
            Kirigami.Icon {
                visible: mr.glyph === ""
                anchors.centerIn: parent
                width: 26; height: 26
                source: mr.icon
                fallback: "audio-volume-high"
                opacity: mr.entry && mr.entry.Muted ? 0.45 : 1
            }
            Glyph {
                visible: mr.glyph !== ""
                anchors.centerIn: parent
                name: mr.glyph; fallback: "audio-speakers-symbolic"
                size: 24; wght: 300
                color: page.pal.text1
                opacity: mr.entry && mr.entry.Muted ? 0.45 : 1
                fontAvailable: page.pal.hasIconFont
            }
            Glyph {
                visible: !!mr.entry && !!mr.entry.Muted
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                name: "volume_off"; fallback: "audio-volume-muted"
                size: 14; wght: 400
                color: page.pal.text1
                fontAvailable: page.pal.hasIconFont
            }
            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (mr.entry) mr.entry.Muted = !mr.entry.Muted
            }
            QQC2.ToolTip.visible: muteArea.containsMouse
            QQC2.ToolTip.text: (mr.entry && mr.entry.Muted ? "Unmute " : "Mute ") + mr.label
            QQC2.ToolTip.delay: 500
        }
        LevelSlider {
            id: slider
            pal: page.pal
            Layout.fillWidth: true
            enabled: !mr.entry || mr.entry.VolumeWritable !== false
            onMoved: v => {
                if (!mr.entry) return;
                mr.entry.Volume = page.rawOf(v);
                if (mr.entry.Muted && v > 0) mr.entry.Muted = false;
            }
        }
    }

    // ---- bottom: More volume settings ----
    Item {
        id: footer
        y: header.height + flick.height
        width: parent.width
        height: 52
        Rectangle { width: parent.width; height: 1; color: page.pal.divider }
        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: moreText.implicitWidth + 20
            height: 34
            radius: 6
            color: moreArea.containsMouse ? page.pal.tintHover : "transparent"
            Text {
                id: moreText
                anchors.centerIn: parent
                text: "More volume settings"
                font.family: page.pal.font
                font.pixelSize: 13
                color: page.pal.text1
            }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.more()
            }
        }
    }
}
