pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {

    id: root

    required property var theme
    required property Item target

    property var bluetoothData: ({})
    property bool busy: false
    property string busyTarget: ""
    property string errorText: ""
    property string errorTarget: ""
    property bool isScanning: false

    signal openedChanged(bool opened)
    signal refreshRequested()
    signal powerToggleRequested(bool enabled)
    signal deviceConnectRequested(string mac)
    signal deviceDisconnectRequested(string mac)
    signal devicePairRequested(string mac)
    signal deviceRemoveRequested(string mac)
    signal settingsRequested()

    readonly property bool powered: Boolean(bluetoothData?.powered)
    readonly property bool available: bluetoothData?.available !== false
    readonly property var connectedDevices: bluetoothData?.connected ?? []
    readonly property var pairedDevices: bluetoothData?.paired_devices ?? []
    readonly property var discoveredDevices: bluetoothData?.discovered ?? []
    property string deviceFilter: ""
    readonly property var filteredConnectedDevices: filterDevices(connectedDevices)
    readonly property var filteredPairedDevices: filterDevices(pairedDevices)
    readonly property var filteredDiscoveredDevices: filterDevices(discoveredDevices)
    readonly property int deviceCount: connectedDevices.length + pairedDevices.length + discoveredDevices.length
    readonly property int filteredDeviceCount: filteredConnectedDevices.length
                                                + filteredPairedDevices.length
                                                + filteredDiscoveredDevices.length

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    readonly property real fixedHeaderHeight: 14 + 38 + 10 + 1 + 10 + 14 // 87px
    implicitWidth: root.theme.popupWidths.large
    implicitHeight: Math.min(540, fixedHeaderHeight + Math.min(420, scrollContent.implicitHeight))

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {

        root.openedChanged(visible)
        if (visible) {
            card.forceActiveFocus()
        }
    }

    function filterDevices(devices) {
        const query = deviceFilter.trim().toLowerCase()
        if (query.length === 0)
            return devices
        return devices.filter(device => {
            const name = String(device.alias || device.name || "").toLowerCase()
            const mac = String(device.mac || "").toLowerCase()
            return name.includes(query) || mac.includes(query)
        })
    }

    function iconFor(iconName, deviceName) {
        const icon = String(iconName ?? "").toLowerCase()
        const name = String(deviceName ?? "").toLowerCase()
        const full = icon + " " + name

        if (full.includes("headset") || full.includes("headphone") || full.includes("audio")
            || full.includes("earphone") || full.includes("earbuds") || full.includes("moondrop")
            || full.includes("airpods") || full.includes("buds") || full.includes("sound") || full.includes("speaker"))
            return "headphones"
        if (full.includes("gamepad") || full.includes("gaming") || full.includes("controller")
            || full.includes("joystick") || full.includes("xbox") || full.includes("ps4")
            || full.includes("ps5") || full.includes("dualshock") || full.includes("dualsense"))
            return "bar-game"
        if (full.includes("keyboard") || full.includes("teclado") || full.includes("keychron"))
            return "bar-keyboard"
        if (full.includes("mouse") || full.includes("trackpad") || full.includes("pointer"))
            return "mouse"
        if (full.includes("phone") || full.includes("iphone") || full.includes("android")
            || full.includes("galaxy") || full.includes("pixel") || full.includes("smartphone"))
            return "device-mobile"
        if (full.includes("computer") || full.includes("pc") || full.includes("laptop")
            || full.includes("desktop") || full.includes("macbook"))
            return "device-desktop"
        if (full.includes("watch") || full.includes("relogio") || full.includes("band"))
            return "bar-clock"

        return "bluetooth"
    }

    function batteryIcon(percentage) {
        const p = Number(percentage)
        if (p >= 90) return "󰁹"
        if (p >= 70) return "󰂁"
        if (p >= 50) return "󰁿"
        if (p >= 30) return "󰁽"
        if (p >= 15) return "󰁻"
        return "󰁺"
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        cardClip: true

        Keys.onEscapePressed: root.visible = false

        PopupHeader {
            id: headerSection
            theme: root.theme
            leadingTablerIcon: !root.powered ? "bluetooth-off" : "bluetooth"
            leadingIconColor: !root.powered
                              ? root.theme.grey
                              : (root.connectedDevices.length > 0 ? root.theme.primary : root.theme.secondary)
            title: "Bluetooth"
            subtitle: root.busyTarget === "__power__"
                      ? "Aplicando alteração…"
                      : (root.errorTarget === "__power__" && root.errorText.length > 0
                         ? root.errorText
                         : (!root.available
                            ? "Bluetooth indisponível"
                            : (!root.powered
                               ? "Desligado"
                               : (root.connectedDevices.length > 0
                                  ? (String(root.connectedDevices[0].alias || root.connectedDevices[0].name) +
                                     (root.connectedDevices[0].battery >= 0 ? " • " + root.connectedDevices[0].battery + "%" : "") +
                                     (root.connectedDevices.length > 1 ? " (+" + (root.connectedDevices.length - 1) + ")" : ""))
                                  : (root.isScanning ? "Procurando dispositivos…" : "Pronto para conectar")))))
            subtitleColor: root.errorTarget === "__power__" && root.errorText.length > 0
                           ? root.theme.red
                           : (root.busyTarget === "__power__"
                              ? root.theme.primary
                              : (root.connectedDevices.length > 0
                                 ? root.theme.primary
                                 : root.theme.surfaceVariantForeground))

            // Scan / Refresh Button
            Rectangle {
                width: 26
                height: 26
                radius: root.theme.radiusSm
                visible: root.powered
                anchors.verticalCenter: parent.verticalCenter
                color: root.isScanning
                       ? root.theme.glassActiveSurface
                       : (scanHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface)

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.iconTokens.md
                    height: root.theme.iconTokens.md
                    iconName: "bar-refresh"
                    iconColor: root.isScanning ? root.theme.primary : root.theme.offWhite

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 1200
                        loops: Animation.Infinite
                        running: root.theme.qmlAnimationsEnabled && root.visible && root.powered && root.isScanning
                    }
                }

                HoverHandler { id: scanHover }
                TapHandler {
                    enabled: !root.busy
                    onTapped: root.refreshRequested()
                }
            }

            // Settings Gear Button
            PopupSettingsButton {
                width: 26
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                onClicked: root.settingsRequested()
            }

            // Bluetooth Power Switch
            MaterialSwitch {
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                checked: root.powered
                enabled: root.available && !root.busy
                accessibleLabel: "Bluetooth"
                onClicked: root.powerToggleRequested(checked)
            }
        }

        // 2. Divider Line
        Rectangle {
            id: divider
            anchors.top: headerSection.bottom
            anchors.topMargin: root.theme.popupInsets.standard
            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.outer
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.outer
            height: 1
            color: root.theme.outlineVariant
        }

        // 3. Unified Scroll Area
        Flickable {
            id: scrollArea
            anchors.top: divider.bottom
            anchors.topMargin: root.theme.popupInsets.standard
            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.outer
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.outer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.theme.popupInsets.outer
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: scrollContent.implicitHeight

            WheelKinetic {
                scrollTarget: scrollArea
            }

            Column {
                id: scrollContent
                width: parent.width
                spacing: root.theme.spacingTokens.lg

                // Estado Desligado
                Item {
                    visible: !root.powered
                    width: parent.width
                    height: 48

                    Row {
                        anchors.centerIn: parent
                        spacing: root.theme.spacingTokens.md

                        TablerIcon {
                            width: root.theme.iconTokens.lg
                            height: root.theme.iconTokens.lg
                            iconName: "bluetooth-off"
                            iconColor: root.theme.surfaceVariantForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Ligue o Bluetooth para conectar dispositivos"
                            color: root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.body
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    visible: root.powered && root.deviceCount >= 4
                    width: parent.width
                    height: visible ? 32 : 0
                    radius: root.theme.radiusSm
                    color: root.theme.glassCardSurface
                    border.width: deviceSearch.activeFocus ? 1 : 0
                    border.color: root.theme.primary

                    SearchField {
                        id: deviceSearch
                        theme: root.theme
                        anchors.fill: parent
                        anchors.leftMargin: root.theme.popupInsets.standard
                        anchors.rightMargin: root.theme.popupInsets.standard
                        placeholderText: "Buscar dispositivo…"
                        placeholderColor: root.theme.surfaceVariantForeground
                        font.pixelSize: root.theme.typeTokens.body
                        debounceInterval: 120
                        onQueryChanged: function(query) { root.deviceFilter = query }
                    }
                }

                EmptyState {
                    visible: root.powered
                             && root.deviceFilter.trim().length > 0
                             && root.filteredDeviceCount === 0
                    width: parent.width
                    height: 40
                    theme: root.theme
                    title: "Nenhum dispositivo corresponde à busca"
                    titleSize: root.theme.typeTokens.meta
                }

                // 1. CONECTADOS SECTION
                Column {
                    visible: root.powered && root.filteredConnectedDevices.length > 0
                    width: parent.width
                    spacing: root.theme.spacingTokens.xsPlus

                    Text {
                        text: "CONECTADOS"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.filteredConnectedDevices

                            delegate: PopupListRow {
                                id: connCard
                                required property var modelData
                                theme: root.theme
                                rowHeight: 44
                                active: true
                                activeBorderColor: root.theme.withAlpha(root.theme.primary, 0.35)
                                readonly property string rowKey: "device:" + String(modelData.mac)
                                readonly property bool isRowBusy: root.busyTarget === rowKey
                                readonly property bool isRowError: root.errorTarget === rowKey && root.errorText.length > 0
                                leadingTablerIcon: root.iconFor(connCard.modelData.icon, connCard.modelData.name)
                                leadingIconColor: root.theme.primary
                                leadingIconPixelSize: root.theme.iconTokens.lgPlus
                                title: String(connCard.modelData.alias || connCard.modelData.name)
                                titlePixelSize: root.theme.typeTokens.subtitle
                                subtitle: connCard.isRowBusy
                                    ? "Desconectando…"
                                    : (connCard.isRowError ? root.errorText : "Conectado")
                                subtitleColor: connCard.isRowError
                                    ? root.theme.red
                                    : root.theme.primary
                                trailing: Row {
                                    spacing: root.theme.spacingTokens.sm

                                    Row {
                                        visible: Number(connCard.modelData.battery) >= 0
                                        spacing: root.theme.spacingTokens.tight

                                        Text {
                                            text: "•"
                                            color: root.theme.surfaceVariantForeground
                                            font.pixelSize: root.theme.typeTokens.caption
                                        }

                                        TablerIcon {
                                            width: root.theme.iconTokens.sm
                                            height: root.theme.iconTokens.sm
                                            iconName: "battery"
                                            iconColor: Number(connCard.modelData.battery) > 20 ? root.theme.green : root.theme.red
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: connCard.modelData.battery + "%"
                                            color: root.theme.offWhite
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                        }
                                    }

                                    Rectangle {
                                        width: 72
                                        height: 24
                                        radius: root.theme.radiusSm
                                        color: discHover.hovered
                                            ? root.theme.withAlpha(root.theme.red, 0.25)
                                            : root.theme.withAlpha(root.theme.red, 0.12)
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.red, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Desconectar"
                                            color: root.theme.red
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                        }

                                        HoverHandler { id: discHover }
                                        TapHandler {
                                            onTapped: root.deviceDisconnectRequested(String(connCard.modelData.mac))
                                        }
                                    }
                                }
                            }

                        }
                    }
                }

                // 2. MEUS DISPOSITIVOS (SALVOS) SECTION
                Column {
                    visible: root.powered && root.filteredPairedDevices.length > 0
                    width: parent.width
                    spacing: root.theme.spacingTokens.xsPlus

                    Text {
                        text: "MEUS DISPOSITIVOS"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.filteredPairedDevices

                            delegate: PopupListRow {
                                id: pairedCard
                                required property var modelData
                                theme: root.theme
                                rowHeight: 42
                                readonly property string rowKey: "device:" + String(modelData.mac)
                                readonly property bool isRowBusy: root.busyTarget === rowKey
                                readonly property bool isRowError: root.errorTarget === rowKey && root.errorText.length > 0
                                leadingTablerIcon: root.iconFor(pairedCard.modelData.icon, pairedCard.modelData.name)
                                leadingIconColor: root.theme.offWhite
                                leadingIconPixelSize: root.theme.iconTokens.lgPlus
                                title: String(pairedCard.modelData.alias || pairedCard.modelData.name)
                                subtitle: pairedCard.isRowBusy
                                    ? "Conectando…"
                                    : (pairedCard.isRowError ? root.errorText : "Pareado")
                                subtitleColor: pairedCard.isRowError
                                    ? root.theme.red
                                    : (pairedCard.isRowBusy ? root.theme.primary : root.theme.surfaceVariantForeground)
                                trailing: Row {
                                    spacing: root.theme.spacingTokens.xsPlus

                                    Rectangle {
                                        width: 58
                                        height: 24
                                        radius: root.theme.radiusSm
                                        color: connBtnHover.hovered
                                            ? root.theme.withAlpha(root.theme.primary, 0.25)
                                            : root.theme.withAlpha(root.theme.primary, 0.12)
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.primary, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Conectar"
                                            color: root.theme.primary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }

                                        HoverHandler { id: connBtnHover }
                                        TapHandler {
                                            onTapped: root.deviceConnectRequested(String(pairedCard.modelData.mac))
                                        }
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: root.theme.radiusSm
                                        color: forgetHover.hovered
                                            ? root.theme.withAlpha(root.theme.red, 0.25)
                                            : "transparent"

                                        TablerIcon {
                                            anchors.centerIn: parent
                                            width: root.theme.iconTokens.smPlus
                                            height: root.theme.iconTokens.smPlus
                                            iconName: "dashboard-trash"
                                            iconColor: forgetHover.hovered ? root.theme.red : root.theme.surfaceVariantForeground
                                        }

                                        HoverHandler { id: forgetHover }
                                        TapHandler {
                                            onTapped: root.deviceRemoveRequested(String(pairedCard.modelData.mac))
                                        }
                                    }
                                }

                            }
                        }
                    }
                }

                // 3. DISPOSITIVOS PRÓXIMOS SECTION
                Column {
                    visible: root.powered
                             && (root.filteredDiscoveredDevices.length > 0
                                 || (root.discoveredDevices.length === 0
                                     && root.deviceFilter.trim().length === 0))
                    width: parent.width
                    spacing: root.theme.spacingTokens.xsPlus

                    Row {
                        width: parent.width
                        height: 18
                        spacing: root.theme.spacingTokens.sm

                        Text {
                            text: "DISPOSITIVOS PRÓXIMOS"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: root.isScanning
                            text: "• Buscando…"
                            color: root.theme.primary
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.caption
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Mensagem de lista vazia
                    Item {
                        visible: root.filteredDiscoveredDevices.length === 0
                                 && root.deviceFilter.trim().length === 0
                        width: parent.width
                        height: 28

                        EmptyState {
                            anchors.fill: parent
                            theme: root.theme
                            title: root.isScanning
                                   ? "Procurando dispositivos próximos…"
                                   : "Nenhum dispositivo novo encontrado."
                            titleSize: root.theme.typeTokens.meta
                            titleColor: root.theme.foreground
                        }
                    }

                    Column {
                        visible: root.discoveredDevices.length > 0
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.filteredDiscoveredDevices

                            delegate: PopupListRow {
                                                                id: discovCard
                                required property var modelData
                                theme: root.theme
                                rowHeight: 40
                                readonly property string rowKey: "device:" + String(modelData.mac)
                                readonly property bool isRowBusy: root.busyTarget === rowKey
                                readonly property bool isRowError: root.errorTarget === rowKey && root.errorText.length > 0
                                leadingTablerIcon: root.iconFor(discovCard.modelData.icon, discovCard.modelData.name)
                                leadingIconColor: root.theme.offWhite
                                leadingIconPixelSize: root.theme.iconTokens.lgPlus
                                title: String(discovCard.modelData.alias || discovCard.modelData.name)
                                subtitle: discovCard.isRowBusy
                                    ? "Pareando…"
                                    : (discovCard.isRowError ? root.errorText : "Dispositivo próximo")
                                subtitleColor: discovCard.isRowError
                                    ? root.theme.red
                                    : (discovCard.isRowBusy ? root.theme.primary : root.theme.surfaceVariantForeground)
                                trailing: Rectangle {
                                    width: 56
                                    height: 24
                                    radius: root.theme.radiusSm
                                    color: pairBtnHover.hovered
                                        ? root.theme.withAlpha(root.theme.primary, 0.25)
                                        : root.theme.withAlpha(root.theme.primary, 0.12)
                                    border.width: 1
                                    border.color: root.theme.withAlpha(root.theme.primary, 0.30)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: root.theme.spacingTokens.tight

                                        TablerIcon {
                                            width: root.theme.iconTokens.xs
                                            height: root.theme.iconTokens.xs
                                            iconName: "dashboard-plus"
                                            iconColor: root.theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Parear"
                                            color: root.theme.primary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    HoverHandler { id: pairBtnHover }
                                    TapHandler {
                                        onTapped: root.devicePairRequested(String(discovCard.modelData.mac))
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }

        // 4. Sleek Vertical Scroll Indicator
        Rectangle {
            id: scrollIndicator
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.micro
            y: scrollArea.y + (scrollArea.contentY / Math.max(1, scrollArea.contentHeight)) * scrollArea.height
            width: 3
            height: Math.max(20, (scrollArea.height / Math.max(1, scrollArea.contentHeight)) * scrollArea.height)
            radius: 1.5
            color: root.theme.withAlpha(root.theme.foreground, 0.35)
            visible: scrollArea.contentHeight > scrollArea.height
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
