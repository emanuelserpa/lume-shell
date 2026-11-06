pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import "BatteryAlertLogic.js" as BatteryAlertLogic
import qs.services

QtObject {
    id: root

    readonly property var battery: UPower.displayDevice
    property string lastLevel: ""
    property bool wasCharging: false

    function urgencyForName(name) {
        if (name === "critical") return NotificationUrgency.Critical
        if (name === "low") return NotificationUrgency.Low
        return NotificationUrgency.Normal
    }

    function evaluate() {
        const device = root.battery
        if (!device || !device.ready) return

        const percentage = Math.floor(device.percentage * 100)
        const isPlugged = device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged
        const isDischarging = device.state === UPowerDeviceState.Discharging
        const next = BatteryAlertLogic.transition(
            root.lastLevel,
            root.wasCharging,
            percentage,
            isDischarging,
            isPlugged
        )

        root.lastLevel = next.level
        root.wasCharging = next.wasCharging
        // Clear stale battery alerts even when the shell starts while plugged
        // in and the transition does not produce a "charger connected" notice.
        if (isPlugged) NotificationState.dismissBatteryAlerts()
        if (!next.notice) return

        NotificationState.postInternalNotification({
            appName: "Battery",
            appIcon: next.notice.appIcon,
            summary: next.notice.summary,
            body: next.notice.body,
            urgency: root.urgencyForName(next.notice.urgency),
            replaceKey: isPlugged ? "battery-charging" : "battery-alert",
            expireAfterMs: isPlugged ? 2500 : 0
        })
    }

    function start() {
        root.evaluate()
    }

    property Connections batteryChanges: Connections {
        target: root.battery
        function onReadyChanged() { root.evaluate() }
        function onPercentageChanged() { root.evaluate() }
        function onStateChanged() { root.evaluate() }
    }
}
