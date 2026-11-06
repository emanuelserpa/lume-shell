import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "../services/CommandResult.js" as CommandResult
import "../services/NetworkActionLogic.js" as NetworkActionLogic

Item {
    id: root

    required property var theme
    property bool plain: false

    implicitWidth: root.theme ? root.theme.barIndicatorSize : pill.implicitWidth
    implicitHeight: root.theme ? root.theme.pillHeight : 25

    property alias activeError: actionFeedback.errorText
    property alias activeErrorTarget: actionFeedback.errorTarget
    property alias actionBusyTarget: actionFeedback.busyTarget
    property alias actionBusy: actionFeedback.busy
    property string pendingInput: ""
    property bool wifiScanLoading: false
    property Item popupTarget: null
    property Item popupActivationTarget: null
    readonly property bool popupVisible: popup.visible

    ActionFeedback { id: actionFeedback }

    readonly property var networkData: networkState.result.data

    readonly property var activeVpns: {
        const list = networkData.vpns ?? []
        return list.filter(function(vpn) { return Boolean(vpn.active) })
    }

    readonly property bool vpnActive: activeVpns.length > 0

    readonly property string activeVpnNames: activeVpns
        .map(function(vpn) { return String(vpn.name ?? "") })
        .filter(function(name) { return name.length > 0 })
        .join(", ")

    readonly property var popupData: {
        const state = networkData
        const scan = networkScan.result.data
        return {
            text: state.text ?? "",
            tooltip: state.tooltip ?? "",
            wifi_enabled: Boolean(state.wifi_enabled),
            active_ssid: state.active_ssid ?? "",
            active_connection: state.active_connection ?? "",
            active_device: state.active_device ?? "",
            active_type: state.active_type ?? "none",
            active_ip: state.active_ip ?? "",
            active_signal: Number(state.active_signal ?? 0),
            active_freq: state.active_freq ?? "",
            rx_bytes: Number(state.rx_bytes ?? 0),
            tx_bytes: Number(state.tx_bytes ?? 0),
            portal: Boolean(state.portal),
            networks: scan.networks ?? [],
            vpns: state.vpns ?? [],
            status: state.status ?? "ok"
        }
    }

    // Dynamic interval: 2s when popup is open for live telemetry, 8s when closed.
    CommandJson {
        id: networkState
        command: ["python3", Quickshell.shellDir + "/scripts/network-status.py"]
        interval: popup.visible ? 2000 : 8000
    }

    // Expensive Wi‑Fi scan: only called explicitly.
    CommandJson {
        id: networkScan
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/network-status.py",
            "--scan"
        ]
        interval: 0
        autoStart: false
        onGenerationChanged: root.wifiScanLoading = false
    }

    function refreshState() {
        networkState.refresh()
    }

    function refreshScan() {
        root.wifiScanLoading = true
        networkScan.refresh()
    }

    function refreshPopup() {
        refreshState()
        refreshScan()
    }

    function openPopup(targetItem) {
        root.popupActivationTarget = targetItem ?? null
        if (passwordDialog.visible)
            passwordDialog.visible = false
        if (!popup.visible) {
            popup.visible = true
            root.refreshPopup()
        }
    }

    function togglePopup(targetItem) {
        if (popup.visible) {
            popup.visible = false
        } else {
            root.openPopup(targetItem)
        }
    }

    function runAction(args, quiet, target, input) {
        if (actionProc.running)
            return

        root.pendingInput = input === undefined ? "" : String(input)
        actionFeedback.begin(target, quiet)

        actionProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/network-action.py"
        ].concat(args)
        actionProc.running = true
    }

    Process {
        id: actionProc
        stdinEnabled: true

        onStarted: {
            if (root.pendingInput.length > 0) {
                actionProc.write(root.pendingInput + "\n")
                root.pendingInput = ""
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                const obj = response.data

                if (response.ok && obj.action === "wifi-qr") {
                    popup.qrData = obj
                    popup.showQr = true
                }

                if (response.ok && obj.action === "connect-password")
                    passwordDialog.visible = false

                if (!response.ok)
                    actionFeedback.fail(String(response.error ?? "A operação de rede falhou."))
                else
                    actionFeedback.succeed()
            }
        }

        onRunningChanged: {
            if (!running) {
                root.pendingInput = ""
                actionFeedback.finish()
                refreshDelay.restart()
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 700
        repeat: false
        onTriggered: {
            root.refreshState()
            if (popup.visible)
                root.refreshScan()
        }
    }

    readonly property string networkType: String(root.networkData.active_type ?? "")
    readonly property string activeSsid: String(root.networkData.active_ssid ?? "").trim()
    readonly property bool wifiEnabled: Boolean(root.networkData.wifi_enabled)
    readonly property bool hasConnection: activeSsid.length > 0 || networkType === "ethernet"
    readonly property string wifiIcon: {
        if (!root.hasConnection) return "bar-wifi-zero"
        const sig = Number(root.networkData.active_signal ?? 0)
        if (sig >= 60) return "bar-wifi"
        if (sig >= 40) return "bar-wifi-medium"
        if (sig >= 20) return "bar-wifi-low"
        return "bar-wifi-zero"
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: ""
        tablerIcon: root.networkType === "ethernet" ? "bar-ethernet" : root.wifiIcon
        iconSize: root.theme.barIconSize
        fontPixelSize: root.theme.iconTokens.lg
        textColor: root.hasConnection || root.vpnActive
                   ? root.theme.surfaceForeground
                   : root.theme.surfaceVariantForeground
        highlighted: popup.visible

        tooltipText: {
            const baseTooltip = root.networkType === "ethernet"
                                ? "Conectado por cabo"
                                : (root.activeSsid.length > 0
                                   ? "Conectado a " + root.activeSsid
                                   : (root.wifiEnabled ? "Wi‑Fi disponível" : "Wi‑Fi desligado"))
            if (!root.vpnActive)
                return baseTooltip
            const vpnDesc = root.activeVpnNames.length > 0
                            ? "VPN: " + root.activeVpnNames
                            : "VPN conectada"
            return baseTooltip + " • " + vpnDesc
        }

        TablerIcon {
            visible: root.vpnActive
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.theme.spacingTokens.micro
            anchors.bottomMargin: root.theme.spacingTokens.micro
            width: root.theme.iconTokens.xs
            height: root.theme.iconTokens.xs
            iconName: "bar-lock"
            iconColor: root.theme.green
            z: 2
        }

        NetworkPopup {
            id: popup
            theme: root.theme
            target: root.popupActivationTarget
                    ? root.popupActivationTarget
                    : (root.popupTarget ? root.popupTarget : pill)
            networkData: root.popupData
            wifiStateReady: networkState.generation > 0
            wifiScanLoading: root.wifiScanLoading
            errorText: root.activeError
            errorTarget: root.activeErrorTarget
            busy: root.actionBusy
            busyTarget: root.actionBusyTarget

            onRefreshRequested: root.refreshPopup()

            onWifiToggleRequested: function(enabled) {
                root.runAction([enabled ? "wifi-on" : "wifi-off"], false, "__wifi__")
            }

            onDisconnectRequested: function(device) {
                root.runAction(["disconnect", device], false, "wifi:" + String(root.popupData.active_ssid ?? ""))
            }

            onConnectRequested: function(ssid, uuid, saved, secure) {
                if (saved && uuid.length > 0) {
                    root.runAction(["connect-saved", uuid], false, "wifi:" + ssid)
                } else if (!secure) {
                    root.runAction(["connect-open", ssid], false, "wifi:" + ssid)
                } else {
                    popup.visible = false
                    Qt.callLater(function() { passwordDialog.openFor(ssid) })
                }
            }

            onPasswordPromptRequested: function(ssid, uuid) {
                popup.visible = false
                Qt.callLater(function() { passwordDialog.openFor(ssid, uuid) })
            }

            onQrRequested: function() {
                root.runAction(["wifi-qr"], false, "__qr__")
            }

            onCopyRequested: function(text) {
                root.runAction(["copy"], true, "", text)
            }

            onOpenPortalRequested: {
                root.runAction(["open-portal"], true, "")
            }

            onVpnToggleRequested: function(uuid, enabled) {
                root.runAction(
                    NetworkActionLogic.vpnSetArguments(uuid, enabled),
                    false,
                    "vpn:" + uuid
                )
            }

            onSettingsRequested: root.runAction(["editor"], true, "")
            onVisibleChanged: if (!visible) root.popupActivationTarget = null
        }

        NetworkPasswordDialog {
            id: passwordDialog
            theme: root.theme
            target: pill
            errorText: root.activeErrorTarget === "wifi:" + ssid ? root.activeError : ""
            busy: root.actionBusy && root.actionBusyTarget === "wifi:" + ssid
            onConnectRequested: function(ssid, password) {
                const args = passwordDialog.uuid.length > 0
                    ? ["connect-password", ssid, passwordDialog.uuid]
                    : ["connect-password", ssid]
                root.runAction(args, false, "wifi:" + ssid, password)
            }
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (passwordDialog.visible) {
                    passwordDialog.visible = false
                    return
                }
                const opening = !popup.visible
                popup.visible = opening

                if (opening) {
                    // This is the only automatic path that triggers a Wi-Fi scan.
                    root.refreshPopup()
                }
            } else if (mouse.button === Qt.MiddleButton) {
                const action = root.wifiEnabled ? "wifi-off" : "wifi-on"
                root.runAction([action], true, "__wifi__")
            } else if (mouse.button === Qt.RightButton) {
                // Explicit user refresh may scan even with popup closed.
                root.refreshPopup()
            }
        }
    }
}
