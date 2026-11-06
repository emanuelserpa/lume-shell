pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as Effects
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.services

Pill {
    id: root

    readonly property var bat: UPower.displayDevice
    readonly property real pct: bat?.ready ? bat.percentage * 100 : 0
    readonly property bool charging: bat?.state === UPowerDeviceState.Charging
    readonly property bool plugged: charging || bat?.state === UPowerDeviceState.FullyCharged
    readonly property real watts: bat?.ready ? Math.abs(bat.changeRate) : 0
    readonly property real secondsRemaining:
        !bat?.ready ? 0 : (charging ? bat.timeToFull : bat.timeToEmpty)
    readonly property bool nativeHealthAvailable: Boolean(bat?.ready && bat.healthSupported)
    readonly property bool healthAvailable:
        nativeHealthAvailable || Boolean(batteryHealthState.result.data?.available)
    readonly property real healthPercentage:
        nativeHealthAvailable
        ? Number(bat.healthPercentage)
        : Number(batteryHealthState.result.data?.health_percentage ?? 0)

    readonly property string profileError: PowerProfileState.error
    readonly property bool profileBusy: PowerProfileState.busy
    readonly property string chargeLimitError: chargeLimitAction.error
    readonly property bool chargeLimitBusy: chargeLimitAction.busy
    readonly property string cpuBoostError: cpuBoostAction.error
    readonly property bool cpuBoostBusy: cpuBoostAction.busy

    onPluggedChanged: {
        if (plugged)
            NotificationState.dismissBatteryAlerts()
    }

    CommandJson {
        id: chargeLimitState
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/battery-charge-limit.py",
            "status"
        ]
        interval: popup.visible ? 8000 : 0
        autoStart: false
    }

    CommandJson {
        id: batteryHealthState
        command: ["python3", Quickshell.shellDir + "/scripts/battery-health.py"]
        autoStart: !root.nativeHealthAvailable
    }

    CommandJson {
        id: cpuBoostState
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/cpu-boost.py",
            "status"
        ]
        interval: popup.visible ? 8000 : 0
        autoStart: false
    }

    CommandAction {
        id: chargeLimitAction
        baseCommand: [
            "python3",
            Quickshell.shellDir + "/scripts/battery-charge-limit.py"
        ]
        fallbackError: "Falha ao alterar o limite."
        refreshTarget: chargeLimitState
    }

    CommandAction {
        id: cpuBoostAction
        baseCommand: [
            "python3",
            Quickshell.shellDir + "/scripts/cpu-boost.py"
        ]
        fallbackError: "Falha ao alterar o boost do processador."
        refreshTarget: cpuBoostState
    }

    function setChargeLimit(mode) {
        chargeLimitAction.run(["set", mode])
    }

    function setProfile(profile) {
        PowerProfileState.setProfile(profile)
    }

    function setCpuBoost(enabled) {
        cpuBoostAction.run(["set", enabled ? "on" : "off"])
    }

    text: ""
    implicitWidth: batteryGlyph.width + root.theme.spacingTokens.md

    Item {
        id: batteryGlyph
        anchors.centerIn: parent
        width: batteryBody.width + 4 + (root.charging ? 12 : 0)
        height: root.theme.iconTokens.xxlPlus
        z: 2

        readonly property real chargeWidth: batteryBody.width * Math.max(0, Math.min(100, root.pct)) / 100
        readonly property string percentageText: root.bat?.ready ? String(Math.round(root.pct)) : "?"
        readonly property color inkColor: {
            const c = root.textColor
            const bright = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.5
            return bright
                ? (root.theme.isLight ? root.theme.foreground : root.theme.backgroundOpaque)
                : (root.theme.isLight ? root.theme.backgroundOpaque : root.theme.foreground)
        }

        Rectangle {
            id: batteryBody
            width: root.theme.iconTokens.mediaControl + 9
            height: parent.height
            radius: 5
            color: Qt.alpha(root.theme.surfaceForeground, 0.16)
            border.width: 0
            border.color: Qt.alpha(root.theme.surfaceForeground, 0.35)
            antialiasing: true

            Item {
                width: batteryGlyph.chargeWidth
                height: parent.height
                clip: true
                visible: Boolean(root.bat?.ready)

                Rectangle {
                    width: batteryBody.width
                    height: batteryBody.height
                    radius: batteryBody.radius
                    color: root.textColor
                    antialiasing: true
                }

            }

            // A single text source avoids independent glyph positioning.
            BatteryMark {
                anchors.fill: parent
                foreground: root.theme.surfaceForeground
                layer.enabled: true
                layer.effect: Effects.LinearGradient {
                    // Soften the charge boundary across a few pixels so it
                    // doesn't read as a baseline shift between adjacent digits.
                    start: Qt.point(batteryGlyph.chargeWidth - 1.5, 0)
                    end: Qt.point(batteryGlyph.chargeWidth + 1.5, 0)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: root.bat?.ready ? batteryGlyph.inkColor : root.theme.surfaceForeground
                        }
                        GradientStop {
                            position: 1
                            color: root.theme.surfaceForeground
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: batteryBody.right
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 5
            radius: 1
            color: Qt.alpha(root.theme.surfaceForeground, 0.55)
        }

        // The state badge is outside the body, so charging never moves the digits.
        Shape {
            visible: root.charging
            x: batteryBody.width + 4
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 14
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: root.theme.surfaceForeground
                PathSvg { path: "M 7 1 L 2 8 L 5.5 8 L 4.5 13 L 10 6 L 6.5 6 Z" }
            }
        }
    }

    // One text silhouette, one baseline; only its ink changes across the fill.
    component BatteryMark: Item {
        id: mark
        required property color foreground

        Text {
            anchors.centerIn: parent
            text: batteryGlyph.percentageText
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.iconTokens.mdPlus
            font.weight: Font.Black
            font.letterSpacing: -0.2
            font.features: { "tnum": 1 }
            color: mark.foreground
        }
    }

    highlighted: popup.visible

    textColor: {
        if (!bat?.ready) return root.theme.offWhite
        if (charging) return root.theme.green
        if (pct <= 15) return root.theme.red
        return root.theme.offWhite
    }

    function formatRemaining(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    tooltipText: {
        const p = Math.round(pct)
        const rem = formatRemaining(secondsRemaining)
        if (charging) {
            return rem ? "Carregando: " + p + "% (" + rem + " até 100%)" : "Carregando: " + p + "%"
        }
        if (plugged) {
            return "Carga completa: " + p + "%"
        }
        return rem ? "Bateria: " + p + "% (" + rem + " restantes)" : "Bateria: " + p + "%"
    }

    BatteryPopup {
        id: popup
        theme: root.theme
        target: root
        percentage: root.pct
        charging: root.charging
        plugged: root.plugged
        watts: root.watts
        secondsRemaining: root.secondsRemaining
        healthAvailable: root.healthAvailable
        healthPercentage: root.healthPercentage
        profileData: PowerProfileState.statusData
        profileBusy: root.profileBusy
        profileError: root.profileError
        cpuBoostData: cpuBoostState.result.data
        cpuBoostBusy: root.cpuBoostBusy
        cpuBoostError: root.cpuBoostError
        chargeLimitData: chargeLimitState.result.data
        chargeLimitBusy: root.chargeLimitBusy
        chargeLimitError: root.chargeLimitError
        stateText: root.charging
                   ? "Carregando"
                   : (root.plugged ? "Carga completa" : "Na bateria")

        onProfileRequested: function(profile) {
            root.setProfile(profile)
        }

        onCpuBoostRequested: function(enabled) {
            root.setCpuBoost(enabled)
        }

        onChargeLimitRequested: function(mode) {
            root.setChargeLimit(mode)
        }
    }

    mouseArea.onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            popup.visible = !popup.visible
            if (popup.visible) {
                PowerProfileState.refresh()
                cpuBoostState.refresh()
                chargeLimitState.refresh()
            }
        }
    }
}
