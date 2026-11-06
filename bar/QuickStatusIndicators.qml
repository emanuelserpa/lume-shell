// LEGADO: componente não montado no shell atual (substituído pelos componentes autônomos bar/Network.qml, bar/Bluetooth.qml e bar/StatusIsland.qml).
pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
    id: root

    required property var theme
    property var networkData: ({})
    property bool networkPopupVisible: false
    property var bluetoothData: ({})
    property bool bluetoothPopupVisible: false

    signal networkDetailsRequested()
    signal networkToggleRequested()
    signal networkRefreshRequested()
    signal bluetoothDetailsRequested()
    signal bluetoothToggleRequested()

    readonly property var indicators: {
        const networkType = String(networkData?.active_type ?? "")
        const ssid = String(networkData?.active_ssid ?? "").trim()
        const wifiEnabled = Boolean(networkData?.wifi_enabled)
        const hasConnection = ssid.length > 0 || networkType === "ethernet"
        const activeVpns = (networkData?.vpns ?? []).filter(vpn => Boolean(vpn.active))
        const vpnActive = activeVpns.length > 0
        const signal = Number(networkData?.active_signal ?? 0)
        const wifiIcon = !hasConnection ? "bar-wifi-zero"
                         : signal >= 60 ? "bar-wifi"
                         : signal >= 40 ? "bar-wifi-medium"
                         : signal >= 20 ? "bar-wifi-low" : "bar-wifi-zero"
        const names = activeVpns
            .map(vpn => String(vpn.name ?? "").trim())
            .filter(name => name.length > 0)
        const connectionTooltip = networkType === "ethernet"
                                  ? "Conectado por cabo"
                                  : (ssid.length > 0
                                     ? "Conectado a " + ssid
                                     : (wifiEnabled ? "Wi‑Fi disponível" : "Wi‑Fi desligado"))

        const entries = [{
            id: "network",
            icon: networkType === "ethernet" ? "bar-ethernet" : wifiIcon,
            color: hasConnection || vpnActive
                   ? root.theme.surfaceForeground
                   : root.theme.surfaceVariantForeground,
            highlighted: root.networkPopupVisible,
            vpnActive: vpnActive,
            tooltip: vpnActive
                     ? connectionTooltip + " • VPN: " + (names.length > 0 ? names.join(", ") : "conectada")
                     : connectionTooltip,
        }]

        if (Boolean(bluetoothData?.available ?? true)) {
            const btPowered = Boolean(bluetoothData?.powered)
            const btConnected = Number(bluetoothData?.connected_count ?? 0) > 0
            entries.push({
                id: "bluetooth",
                icon: btPowered ? "bluetooth" : "bluetooth-off",
                color: btPowered
                       ? (btConnected ? root.theme.primary : root.theme.surfaceForeground)
                       : root.theme.surfaceVariantForeground,
                highlighted: root.bluetoothPopupVisible,
                vpnActive: false,
                tooltip: String(bluetoothData?.tooltip ?? "").trim().length > 0
                         ? String(bluetoothData.tooltip)
                         : (btPowered ? "Bluetooth ligado" : "Bluetooth desligado"),
            })
        }

        return entries
    }

    implicitWidth: indicatorRow.implicitWidth
    implicitHeight: root.theme.pillHeight

    Row {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: root.theme.spacingTokens.xs

        Repeater {
            model: root.indicators

            delegate: Item {
                id: indicator

                required property var modelData
                width: root.theme.barIndicatorSize
                height: root.theme.pillHeight

                Pill {
                    id: indicatorPill
                    anchors.centerIn: parent
                    width: root.theme.barIndicatorSize
                    theme: root.theme
                    plain: true
                    text: ""
                    tablerIcon: indicator.modelData.icon
                    iconSize: root.theme.barIconSize
                    textColor: indicator.modelData.color
                    fontPixelSize: root.theme.iconTokens.lg
                    highlighted: Boolean(indicator.modelData.highlighted)
                    tooltipText: indicator.modelData.tooltip
                    mouseArea.onClicked: function(mouse) {
                        if (indicator.modelData.id === "bluetooth") {
                            if (mouse.button === Qt.LeftButton)
                                root.bluetoothDetailsRequested()
                            else if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton)
                                root.bluetoothToggleRequested()
                            return
                        }
                        if (mouse.button === Qt.LeftButton)
                            root.networkDetailsRequested()
                        else if (mouse.button === Qt.MiddleButton)
                            root.networkToggleRequested()
                        else if (mouse.button === Qt.RightButton)
                            root.networkRefreshRequested()
                    }
                }

                TablerIcon {
                    visible: indicator.modelData.vpnActive ?? false
                    anchors.right: indicatorPill.right
                    anchors.bottom: indicatorPill.bottom
                    anchors.rightMargin: root.theme.spacingTokens.micro
                    anchors.bottomMargin: root.theme.spacingTokens.micro
                    width: root.theme.iconTokens.xs
                    height: root.theme.iconTokens.xs
                    iconName: "bar-lock"
                    iconColor: root.theme.green
                    z: 1
                }

            }
        }
    }
}
