import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Item {
    id: root

    required property var theme
    property bool plain: false

    visible: Boolean(root.bluetoothData.available ?? true)
    implicitWidth: visible ? (root.theme ? root.theme.barIndicatorSize : pill.implicitWidth) : 0
    implicitHeight: root.theme ? root.theme.pillHeight : 25

    property alias activeError: actionFeedback.errorText
    property alias activeErrorTarget: actionFeedback.errorTarget
    property alias actionBusyTarget: actionFeedback.busyTarget
    property alias actionBusy: actionFeedback.busy
    readonly property var bluetoothData: bluetoothState.result.data
    property Item popupTarget: null
    property Item popupActivationTarget: null
    readonly property bool popupVisible: popup.visible

    ActionFeedback { id: actionFeedback }

    CommandJson {
        id: bluetoothState
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/bluetooth-status.py"
        ]
        interval: popup.visible ? 2000 : 8000
    }

    function refresh() {
        bluetoothState.refresh()
    }

    function openPopup(targetItem) {
        root.popupActivationTarget = targetItem ?? null
        popup.visible = true
    }

    function togglePopup(targetItem) {
        if (popup.visible) {
            popup.visible = false
        } else {
            root.openPopup(targetItem)
        }
    }

    function runAction(args, quiet, target) {
        if (actionProc.busy)
            return

        actionFeedback.begin(target, quiet)
        actionProc.run(args)
    }

    function startDiscovery() {
        if (popup.visible
                && Boolean(root.bluetoothData.available)
                && Boolean(root.bluetoothData.powered)
                && !discoveryProc.running) {
            discoveryProc.running = true
        }
    }

    function stopDiscovery() {
        if (discoveryProc.running)
            discoveryProc.running = false

        if (!discoveryStopProc.running
                && Boolean(root.bluetoothData.available)) {
            discoveryStopProc.running = true
        }
    }

    CommandAction {
        id: actionProc
        baseCommand: [
            "python3",
            Quickshell.shellDir + "/scripts/bluetooth-action.py"
        ]
        fallbackError: "A operação Bluetooth falhou."
        refreshTarget: bluetoothState
        refreshDelay: 650
        onSucceeded: actionFeedback.succeed()
        onFailed: actionFeedback.fail(actionProc.error)
        onFinished: actionFeedback.finish()
    }

    // Keep discovery separate so its long-running command cannot block
    // connect/disconnect/power actions from the popup.
    Process {
        id: discoveryProc
        command: ["bluetoothctl", "scan", "on"]
    }

    Process {
        id: discoveryStopProc
        command: ["bluetoothctl", "scan", "off"]
    }

    Timer {
        id: discoveryRefresh
        interval: 1800
        repeat: true
        running: popup.visible && Boolean(root.bluetoothData.powered)
        onTriggered: {
            root.startDiscovery()
            root.refresh()
        }
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: ""
        tablerIcon: Boolean(root.bluetoothData.powered) ? "bluetooth" : "bluetooth-off"
        iconSize: root.theme.barIconSize
        fontPixelSize: root.theme.iconTokens.lg
        textColor: Boolean(root.bluetoothData.powered)
                   ? (Number(root.bluetoothData.connected_count ?? 0) > 0
                      ? root.theme.primary
                      : root.theme.surfaceForeground)
                   : root.theme.surfaceVariantForeground
        highlighted: popup.visible
        tooltipText: String(root.bluetoothData.tooltip ?? "").trim().length > 0
                     ? String(root.bluetoothData.tooltip)
                     : (Boolean(root.bluetoothData.powered) ? "Bluetooth ligado" : "Bluetooth desligado")

        BluetoothPopup {
            id: popup
            theme: root.theme
            target: root.popupActivationTarget
                    ? root.popupActivationTarget
                    : (root.popupTarget ? root.popupTarget : pill)
            bluetoothData: root.bluetoothData
            busy: root.actionBusy
            busyTarget: root.actionBusyTarget
            errorText: root.activeError
            errorTarget: root.activeErrorTarget
            isScanning: discoveryProc.running

            onOpenedChanged: function(opened) {
                if (opened) {
                    root.refresh()
                    root.startDiscovery()
                } else {
                    root.stopDiscovery()
                    root.popupActivationTarget = null
                }
            }

            onRefreshRequested: {
                root.refresh()
                root.startDiscovery()
            }

            onPowerToggleRequested: function(enabled) {
                if (!enabled)
                    root.stopDiscovery()

                root.runAction(
                    [enabled ? "power-on" : "power-off"],
                    false,
                    "__power__"
                )
            }

            onDeviceConnectRequested: function(mac) {
                root.runAction(["connect", mac], false, "device:" + mac)
            }

            onDeviceDisconnectRequested: function(mac) {
                root.runAction(["disconnect", mac], false, "device:" + mac)
            }

            onDevicePairRequested: function(mac) {
                root.runAction(["pair", mac], false, "device:" + mac)
            }

            onDeviceRemoveRequested: function(mac) {
                root.runAction(["remove", mac], false, "device:" + mac)
            }

            onSettingsRequested: Quickshell.execDetached(["blueberry"])
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                popup.visible = !popup.visible
            } else if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                if (!Boolean(root.bluetoothData.available))
                    return

                const enabled = !Boolean(root.bluetoothData.powered)
                root.runAction(
                    [enabled ? "power-on" : "power-off"],
                    true,
                    "__power__"
                )
            }
        }
    }
}
