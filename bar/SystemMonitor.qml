import QtQuick
import Quickshell
import qs.components

Pill {
    id: root

    property Item popupTarget: null
    plain: true
    function openPopup() { detailsPopup.visible = true }

    readonly property var usage: usageState.result.data
    readonly property var cpu: usage.cpu ?? ({})
    readonly property var memory: usage.memory ?? ({})
    readonly property var sensors: sensorState.result.data ?? ({})
    readonly property var temperatureData: sensors.temperature ?? ({})
    readonly property var fanData: sensors.fan ?? ({})
    property double previousTotal: 0
    property double previousIdle: 0
    readonly property int cpuPercent: {
        if (!usageState.result.ok || cpu.percent === null || cpu.percent === undefined)
            return -1
        return Math.max(0, Math.min(100, Math.round(Number(cpu.percent))))
    }
    readonly property string cpuText: cpuPercent >= 0 ? cpuPercent + "%" : "--"
    readonly property color cpuUsageColor: cpuPercent >= 90 ? root.theme.red
                                           : cpuPercent >= 70 ? root.theme.yellow
                                           : root.theme.surfaceForeground
    readonly property string cpuUsageLabel: cpuPercent >= 90 ? "alto"
                                             : cpuPercent >= 70 ? "elevado"
                                             : "normal"
    readonly property int cpuFrequencyMhz: Number(cpu.frequency_mhz) || 0

    tablerIcon: "bar-cpu"
    iconSize: root.theme.barIconSize
    textColor: root.theme.surfaceForeground
    iconColor: cpuPercent >= 0 ? root.cpuUsageColor : root.theme.surfaceVariantForeground
    text: ""
    highlighted: detailsPopup.visible
    tooltipText: cpuPercent >= 0
        ? "Uso da CPU " + root.cpuUsageLabel + ": " + root.cpuText
        : "Uso da CPU indisponível"

    mouseArea.onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton)
            detailsPopup.visible = !detailsPopup.visible
    }

    SystemMonitorPopup {
        id: detailsPopup
        theme: root.theme
        target: root.popupTarget ? root.popupTarget : root
        memoryUsedMb: Number(root.memory.used_mb) || 0
        memoryTotalMb: Number(root.memory.total_mb) || 0
        memoryPercent: Number(root.memory.percent) || 0
        cpuFrequencyMhz: root.cpuFrequencyMhz
        temperature: Number(root.temperatureData.temp_c) || 0
        fanRpm: Number(root.fanData.rpm) || 0
        fanSensor: String(root.fanData.sensor ?? "unavailable")
        fanPwmPercent: Number(root.fanData.pwm_percent) || 0
    }

    CommandJson {
        id: sensorState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/hardware-sensors.py"]
        autoStart: detailsPopup.visible
        interval: detailsPopup.visible ? 3000 : 0
    }

    Connections {
        target: detailsPopup
        function onVisibleChanged() {
            if (detailsPopup.visible)
                sensorState.refresh()
        }
    }

    CommandJson {
        id: usageState
        command: [
            "python3",
            "-B",
            Quickshell.shellDir + "/scripts/system-usage.py",
            String(root.previousTotal),
            String(root.previousIdle)
        ]
        interval: 5000

        onResultChanged: {
            if (!usageState.result.ok)
                return
            const cpuData = usageState.result.data.cpu ?? ({})
            const total = Number(cpuData.total_ticks)
            const idle = Number(cpuData.idle_ticks)
            if (Number.isFinite(total) && Number.isFinite(idle)) {
                root.previousTotal = total
                root.previousIdle = idle
            }
        }
    }
}
