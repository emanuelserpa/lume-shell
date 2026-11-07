pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

// qmllint disable uncreatable-type
PanelWindow {
    // The compositor plugin provides the concrete PanelWindow implementation.
    // qmllint enable uncreatable-type
    id: root

    anchors {
        bottom: true
    }

    // QMargins is valid at runtime; the shipped qmllint metadata cannot
    // resolve its grouped bottom member.
    // qmllint disable missing-property unqualified unresolved-type
    margins.bottom: 72
    // qmllint enable missing-property unqualified unresolved-type
    implicitWidth: 310
    implicitHeight: 68

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    color: "transparent"
    surfaceFormat.opaque: false
    visible: root.showing && root.onFocusedMonitor

    Theme { id: osdTheme }

    property bool showing: false

    // Generic OSD payload. Any future observer can call showGeneric().
    property string osdKind: "volume"
    property string osdLabel: "Volume"
    property string osdIcon: "󰕾"
    property int osdValue: 0
    property int osdMaximum: 100
    property int osdDuration: 1250
    property bool osdMuted: false

    readonly property var hyprMonitor:
        CompositorState.hyprlandNativeEnabled ? Hyprland.monitorFor(root.screen) : null
    readonly property bool onFocusedMonitor: {
        if (CompositorState.mangoCompatibilityEnabled && MangoState.focusedOutput.length > 0) {
            // QuickshellScreenInfo exposes name at runtime; qmllint metadata omits it.
            // qmllint disable missing-property
            return root.screen ? root.screen.name === MangoState.focusedOutput : false
            // qmllint enable missing-property
        }
        if (CompositorState.hyprlandNativeEnabled && root.hyprMonitor !== null
                && root.hyprMonitor !== undefined)
            return Boolean(root.hyprMonitor.focused)
        return Quickshell.screens.length === 0 || root.screen === Quickshell.screens[0]
    }

    function showGeneric(kind, label, icon, newValue, maximum, duration, isMuted) {
        root.osdKind = String(kind)
        root.osdLabel = String(label)
        root.osdIcon = String(icon)
        root.osdMaximum = Math.max(1, Math.round(maximum))
        root.osdValue = Math.max(0, Math.min(root.osdMaximum, Math.round(newValue)))
        root.osdDuration = Math.max(250, Math.round(duration))
        root.osdMuted = Boolean(isMuted)

        hideTimer.interval = root.osdDuration
        root.showing = true
        hideTimer.restart()
    }

    function volumeIcon(v, isMuted) {
        if (isMuted || v <= 0) return "󰖁"
        if (v < 34) return "󰕿"
        if (v < 67) return "󰖀"
        return "󰕾"
    }

    function microphoneIcon(isMuted) {
        return isMuted ? "󰍭" : "󰍬"
    }

    function brightnessIcon(v) {
        if (v <= 25) return "󰃞"
        if (v <= 65) return "󰃟"
        return "󰃠"
    }

    function showVolume(v, isMuted) {
        root.showGeneric(
            "volume",
            isMuted ? "Volume mudo" : "Volume",
            root.volumeIcon(v, isMuted),
            v,
            150,
            1250,
            isMuted
        )
    }

    function showMicrophone(v, isMuted) {
        root.showGeneric(
            "microphone",
            isMuted ? "Microfone mudo" : "Microfone",
            root.microphoneIcon(isMuted),
            v,
            150,
            1250,
            isMuted
        )
    }

    function showBrightness(v) {
        root.showGeneric(
            "brightness",
            "Brilho",
            root.brightnessIcon(v),
            v,
            100,
            1250,
            false
        )
    }

    Timer {
        id: hideTimer
        interval: 1250
        repeat: false
        onTriggered: root.showing = false
    }

    // ----------------------------- Audio ---------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    readonly property int sinkVolume:
        root.sink?.audio ? Math.round(root.sink.audio.volume * 100) : 0

    readonly property bool sinkMuted:
        root.sink?.audio ? Boolean(root.sink.audio.muted) : false

    readonly property int sourceVolume:
        root.source?.audio ? Math.round(root.source.audio.volume * 100) : 0

    readonly property bool sourceMuted:
        root.source?.audio ? Boolean(root.source.audio.muted) : false

    property bool audioReady: false

    property int lastSinkVolume: -1
    property bool lastSinkMuted: false

    property int lastSourceVolume: -1
    property bool lastSourceMuted: false

    Timer {
        interval: 650
        running: true
        repeat: false
        onTriggered: {
            root.lastSinkVolume = root.sinkVolume
            root.lastSinkMuted = root.sinkMuted

            root.lastSourceVolume = root.sourceVolume
            root.lastSourceMuted = root.sourceMuted

            root.audioReady = true
        }
    }

    onSinkVolumeChanged: {
        if (!root.audioReady)
            return

        if (root.sinkVolume !== root.lastSinkVolume) {
            root.lastSinkVolume = root.sinkVolume
            root.showVolume(root.sinkVolume, root.sinkMuted)
        }
    }

    onSinkMutedChanged: {
        if (!root.audioReady)
            return

        if (root.sinkMuted !== root.lastSinkMuted) {
            root.lastSinkMuted = root.sinkMuted
            root.showVolume(root.sinkVolume, root.sinkMuted)
        }
    }

    onSourceVolumeChanged: {
        if (!root.audioReady)
            return

        if (root.sourceVolume !== root.lastSourceVolume) {
            root.lastSourceVolume = root.sourceVolume
            root.showMicrophone(root.sourceVolume, root.sourceMuted)
        }
    }

    onSourceMutedChanged: {
        if (!root.audioReady)
            return

        if (root.sourceMuted !== root.lastSourceMuted) {
            root.lastSourceMuted = root.sourceMuted
            root.showMicrophone(root.sourceVolume, root.sourceMuted)
        }
    }

    // --------------------------- Brightness -------------------------------
    property string backlightDevice: ""
    property int brightnessMax: 0
    property int brightnessValue: 0
    property bool brightnessReady: false

    CommandJson {
        id: discoverBacklight
        command: [
            "python3", "-B",
            Quickshell.shellDir + "/scripts/brightness-status.py"
        ]
        interval: 0
        onPayloadChanged: {
            if (discoverBacklight.result.error === "Aguardando resposta.")
                return
            if (!discoverBacklight.result.ok) {
                console.warn("OSD backlight discovery failed:", discoverBacklight.result.error)
                return
            }
            const device = String(discoverBacklight.result.data.device ?? "").trim()
            if (device.length > 0)
                root.backlightDevice = device
        }
    }

    FileView {
        id: brightnessFile
        path: root.backlightDevice.length > 0
              ? "/sys/class/backlight/" + root.backlightDevice + "/brightness"
              : ""
        watchChanges: true
        printErrors: false

        onFileChanged: {
            this.reload()
            brightnessReload.restart()
        }

        onLoaded: brightnessReload.restart()
    }

    FileView {
        id: brightnessMaxFile
        path: root.backlightDevice.length > 0
              ? "/sys/class/backlight/" + root.backlightDevice + "/max_brightness"
              : ""
        watchChanges: false
        printErrors: false

        onLoaded: brightnessReload.restart()
    }

    Timer {
        id: brightnessReload
        interval: 35
        repeat: false

        onTriggered: {
            let raw = parseInt(brightnessFile.text().trim())
            let max = parseInt(brightnessMaxFile.text().trim())

            if (isNaN(max) || max <= 0)
                max = root.brightnessMax

            if (isNaN(raw) || isNaN(max) || max <= 0)
                return

            const pct = Math.max(0, Math.min(100, Math.round(raw * 100 / max)))

            if (!root.brightnessReady) {
                root.brightnessValue = pct
                root.brightnessReady = true
                return
            }

            if (pct !== root.brightnessValue) {
                root.brightnessValue = pct
                root.showBrightness(pct)
            }
        }
    }

    Component.onCompleted: discoverBacklight.refresh()

    // ----------------------------- Visual --------------------------------
    Rectangle {
        anchors.fill: parent
        radius: osdTheme.radiusPopup
        color: osdTheme.background
        border.width: 1
        border.color: osdTheme.surfaceHover

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: osdTheme.spacingTokens.xl

            Rectangle {
                width: 42
                height: 42
                radius: osdTheme.radiusLg
                anchors.verticalCenter: parent.verticalCenter
                color: osdTheme.glassActiveSurface

                Text {
                    anchors.centerIn: parent
                    text: root.osdIcon
                    color: osdTheme.primary
                    font.family: osdTheme.nerdFontFamily
                    font.pixelSize: osdTheme.typeTokens.metric
                }
            }

            Column {
                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                spacing: osdTheme.spacingTokens.sm

                Row {
                    width: parent.width

                    Text {
                        id: osdLabel
                        text: root.osdLabel
                        color: osdTheme.foreground
                        font.family: osdTheme.fontFamily
                        font.pixelSize: osdTheme.typeTokens.subtitle
                        font.weight: Font.DemiBold
                    }

                    Item {
                        width: parent.width - osdLabel.implicitWidth - osdValue.implicitWidth
                        height: 1
                    }

                    Text {
                        id: osdValue
                        text: root.osdValue + "%"
                        color: osdTheme.primary
                        font.family: osdTheme.fontFamily
                        font.pixelSize: osdTheme.typeTokens.body
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 7
                    radius: height / 2
                    color: osdTheme.sliderTrack

                    Rectangle {
                        width: parent.width * Math.max(
                            0,
                            Math.min(
                                1,
                                root.osdValue / root.osdMaximum
                            )
                        )
                        height: parent.height
                        radius: parent.radius
                        color: osdTheme.primary
                    }
                }
            }
        }
    }
}
