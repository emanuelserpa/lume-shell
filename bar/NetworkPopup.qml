pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var networkData: ({})
    property bool wifiStateReady: false
    property bool wifiScanLoading: false
    property string errorText: ""
    property string errorTarget: ""
    property bool busy: false
    property string busyTarget: ""

    property var qrData: null
    property bool showQr: false
    property bool showQrPassword: false

    // Speedtest state
    property bool showSpeedTest: false
    property bool speedTestRunning: speedTestProc.running
    property string speedTestPhase: "" // "ping" | "download" | "upload" | "done" | "error"
    property real speedTestDown: 0
    property real speedTestUp: 0
    property real speedTestPing: 0
    property real speedTestProgress: 0
    property string speedTestError: ""

    property real prevRx: 0
    property real prevTx: 0
    property real prevTime: 0
    property real downSpeed: 0
    property real upSpeed: 0

    signal refreshRequested()
    signal wifiToggleRequested(bool enabled)
    signal disconnectRequested(string device)
    signal connectRequested(string ssid, string uuid, bool saved, bool secure)
    signal passwordPromptRequested(string ssid, string uuid)
    signal vpnToggleRequested(string uuid, bool enabled)
    signal settingsRequested()
    signal qrRequested()
    signal copyRequested(string text)
    signal openPortalRequested()

    readonly property var networks: networkData?.networks ?? []
    readonly property var vpns: networkData?.vpns ?? []
    property string wifiFilter: ""
    readonly property var filteredNetworks: {
        const query = wifiFilter.trim().toLowerCase()
        return query.length === 0
                ? networks
                : networks.filter(network => String(network.ssid ?? "").toLowerCase().includes(query))
    }
    readonly property bool wifiEnabled: wifiStateReady && Boolean(networkData?.wifi_enabled)
    readonly property string activeSsid: String(networkData?.active_ssid ?? "")
    readonly property string activeDevice: String(networkData?.active_device ?? "")

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
    implicitHeight: Math.min(560, fixedHeaderHeight + Math.min(440, scrollContent.implicitHeight))

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    function toggle() {
        root.visible = !root.visible
    }

    onVisibleChanged: {
        if (!visible) {
            showQr = false
            showSpeedTest = false
            stopSpeedTest()
        } else {
            pingState.refresh()
            card.forceActiveFocus()
        }
    }

    onShowQrChanged: showQrPassword = false

    function startSpeedTest() {
        speedTestError = ""
        speedTestDown = 0
        speedTestUp = 0
        speedTestPing = 0
        speedTestProgress = 0
        speedTestPhase = "ping"
        speedTestProc.running = false
        speedTestProc.running = true
    }

    function stopSpeedTest() {
        speedTestProc.running = false
        if (speedTestPhase !== "done") {
            speedTestPhase = ""
        }
    }

    Process {
        id: speedTestProc
        command: ["python3", Quickshell.shellDir + "/scripts/network-speedtest.py"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const msg = JSON.parse(line.trim())
                    if (msg.error) {
                        root.speedTestError = msg.error
                        root.speedTestPhase = "error"
                        return
                    }
                    root.speedTestPhase = msg.phase || ""
                    if (msg.download_mbps > 0) root.speedTestDown = msg.download_mbps
                    if (msg.upload_mbps > 0) root.speedTestUp = msg.upload_mbps
                    if (msg.ping_ms > 0) root.speedTestPing = msg.ping_ms
                    if (msg.progress !== undefined) root.speedTestProgress = msg.progress
                } catch (e) {}
            }
        }

        onRunningChanged: {
            if (!running && root.speedTestPhase !== "done" && root.speedTestPhase !== "error") {
                root.speedTestPhase = ""
            }
        }
    }

    CommandJson {
        id: pingState
        command: ["bash", Quickshell.shellDir + "/scripts/network-ping.sh"]
        interval: (root.visible && !root.speedTestRunning) ? 3500 : 0
        autoStart: false
    }

    readonly property int pingMs: Number(pingState.result.data.ping ?? -1)

    function formatSpeed(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0) return "0 B/s"
        if (bytesPerSec >= 1048576) return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

    onNetworkDataChanged: {
        const rx = Number(networkData?.rx_bytes ?? 0)
        const tx = Number(networkData?.tx_bytes ?? 0)
        const now = Date.now()

        if (prevTime > 0 && rx >= prevRx && tx >= prevTx) {
            const dt = (now - prevTime) / 1000
            if (dt >= 0.5) {
                downSpeed = (rx - prevRx) / dt
                upSpeed = (tx - prevTx) / dt
            }
        }
        prevRx = rx
        prevTx = tx
        prevTime = now
    }

    function wifiIcon(signal) {
        const s = Number(signal)
        if (s >= 75) return "bar-wifi"
        if (s >= 50) return "bar-wifi-medium"
        if (s >= 25) return "bar-wifi-low"
        return "bar-wifi-zero"
    }

    readonly property string heroTablerIcon: {
        if (networkData?.active_type === "ethernet") return "bar-ethernet"
        if (networkData?.active_type === "wifi") return wifiIcon(networkData?.active_signal ?? 0)
        return "bar-wifi-zero"
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
            leadingTablerIcon: root.heroTablerIcon
            leadingIconColor: (root.networkData?.active_type === "ethernet" || root.activeSsid.length > 0)
                              ? root.theme.primary
                              : (!root.wifiEnabled ? root.theme.foreground : root.theme.secondary)
            title: root.activeSsid.length > 0
                   ? root.activeSsid
                   : (root.networkData?.active_type === "ethernet" ? "Ethernet" : "Sem conexão")
            subtitle: !root.wifiStateReady
                      ? "Carregando estado da rede…"
                      : (root.busyTarget === "__wifi__"
                      ? "Aplicando alteração…"
                      : (root.errorTarget === "__wifi__" && root.errorText.length > 0
                         ? root.errorText
                         : (!root.wifiEnabled
                            ? "Wi‑Fi desligado"
                            : (root.activeSsid.length > 0 || root.networkData?.active_type === "ethernet"
                               ? ((root.networkData?.active_freq ? root.networkData.active_freq + " • " : "") +
                                  (root.networkData?.active_ip ? root.networkData.active_ip : "Conectado"))
                               : "Nenhuma rede conectada"))))
            subtitleColor: root.errorTarget === "__wifi__" && root.errorText.length > 0
                           ? root.theme.red
                           : (root.busyTarget === "__wifi__"
                              ? root.theme.primary
                              : (root.activeSsid.length > 0 || root.networkData?.active_type === "ethernet"
                                 ? root.theme.primary
                                 : root.theme.foreground))

            // Speedtest Button
            Rectangle {
                width: 26
                height: 26
                radius: root.theme.radiusSm
                visible: root.activeSsid.length > 0 || root.networkData?.active_type === "ethernet"
                anchors.verticalCenter: parent.verticalCenter
                color: root.showSpeedTest
                       ? root.theme.glassActiveSurface
                       : (speedTestHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface)

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.iconTokens.mdPlus
                    height: root.theme.iconTokens.mdPlus
                    iconName: "network-speedometer"
                    iconColor: root.showSpeedTest ? root.theme.primary : root.theme.surfaceVariantForeground
                }

                HoverHandler { id: speedTestHover }
                TapHandler {
                    onTapped: {
                        root.showSpeedTest = !root.showSpeedTest
                        if (root.showSpeedTest) {
                            root.showQr = false
                            if (!root.speedTestRunning && root.speedTestPhase !== "done") {
                                root.startSpeedTest()
                            }
                        }
                    }
                }
            }

            // QR Code Button
            Rectangle {
                width: 26
                height: 26
                radius: root.theme.radiusSm
                visible: root.activeSsid.length > 0 && root.networkData?.active_type === "wifi"
                anchors.verticalCenter: parent.verticalCenter
                color: root.showQr
                       ? root.theme.glassActiveSurface
                       : (qrHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface)

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.iconTokens.mdPlus
                    height: root.theme.iconTokens.mdPlus
                    iconName: "network-qr"
                    iconColor: root.showQr ? root.theme.primary : root.theme.surfaceVariantForeground
                }

                HoverHandler { id: qrHover }
                TapHandler {
                    onTapped: {
                        if (root.showQr) {
                            root.showQr = false
                        } else {
                            root.showSpeedTest = false
                            root.qrRequested()
                        }
                    }
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

            // Wi-Fi Power Switch
            MaterialSwitch {
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                checked: root.wifiEnabled
                accessibleLabel: "Wi-Fi"
                onClicked: root.wifiToggleRequested(checked)
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

                // Captive Portal Alert Banner
                Rectangle {
                    id: portalBanner
                    width: parent.width
                    height: 32
                    radius: root.theme.radiusSm
                    visible: Boolean(root.networkData?.portal)
                    color: root.theme.withAlpha(root.theme.yellow, 0.15)
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.yellow, 0.35)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: root.theme.popupInsets.standard
                        anchors.rightMargin: root.theme.popupInsets.standard
                        spacing: root.theme.spacingTokens.md

                        TablerIcon {
                            width: root.theme.iconTokens.mdPlus
                            height: root.theme.iconTokens.mdPlus
                            iconName: "bar-lock"
                            iconColor: root.theme.yellow
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width - 116
                            text: "Esta rede exige acesso pelo navegador"
                            color: root.theme.yellow
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 82
                            height: 22
                            radius: root.theme.radiusXs
                            color: portalBtnHover.hovered ? root.theme.yellow : root.theme.withAlpha(root.theme.yellow, 0.85)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "Abrir portal"
                                color: root.theme.background
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.caption
                                font.weight: Font.Bold
                            }

                            HoverHandler { id: portalBtnHover }
                            TapHandler {
                                onTapped: root.openPortalRequested()
                            }
                        }
                    }
                }

                // Real-time Telemetry Card (Ping + Download + Upload)
                Rectangle {
                    id: telemetryStrip
                    width: parent.width
                    height: 30
                    radius: root.theme.radiusSm
                    visible: root.activeSsid.length > 0 || root.networkData?.active_type === "ethernet"
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Row {
                        anchors.fill: parent

                        // Ping
                        Item {
                            width: (parent.width - 2) / 3
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: root.theme.spacingTokens.xsPlus

                                TablerIcon {
                                    width: root.theme.iconTokens.smPlus
                                    height: root.theme.iconTokens.smPlus
                                    iconName: "network-speedometer"
                                    iconColor: root.pingMs < 0 ? root.theme.red : (root.pingMs < 60 ? root.theme.green : root.theme.yellow)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.pingMs >= 0 ? (root.pingMs + " ms") : "Offline"
                                    color: root.pingMs < 0 ? root.theme.red : (root.pingMs < 60 ? root.theme.green : root.theme.yellow)
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: 1
                            height: 14
                            color: root.theme.outlineVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Download
                        Item {
                            width: (parent.width - 2) / 3
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: root.theme.spacingTokens.xsPlus

                                TablerIcon {
                                    width: root.theme.iconTokens.smPlus
                                    height: root.theme.iconTokens.smPlus
                                    iconName: "dashboard-arrow-down"
                                    iconColor: root.theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.formatSpeed(root.downSpeed)
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: 1
                            height: 14
                            color: root.theme.outlineVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Upload
                        Item {
                            width: (parent.width - 2) / 3
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: root.theme.spacingTokens.xsPlus

                                TablerIcon {
                                    width: root.theme.iconTokens.smPlus
                                    height: root.theme.iconTokens.smPlus
                                    iconName: "dashboard-arrow-up"
                                    iconColor: root.theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.formatSpeed(root.upSpeed)
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Speedtest Card
                Rectangle {
                    id: speedTestCard
                    visible: root.showSpeedTest
                    width: parent.width
                    height: visible ? 108 : 0
                    radius: root.theme.radiusSm
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.theme.popupInsets.standard
                        spacing: root.theme.spacingTokens.smPlus

                        // Speedtest header
                        Item {
                            width: parent.width
                            height: 18

                            Row {
                                spacing: root.theme.spacingTokens.sm
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                TablerIcon {
                                    width: root.theme.iconTokens.md
                                    height: root.theme.iconTokens.md
                                    iconName: "network-speedometer"
                                    iconColor: root.theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Teste de velocidade"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.subtitle
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: {
                                        if (root.speedTestPhase === "ping") return "• Medindo latência…"
                                        if (root.speedTestPhase === "download") return "• Testando download…"
                                        if (root.speedTestPhase === "upload") return "• Testando upload…"
                                        if (root.speedTestPhase === "done") return "• Concluído!"
                                        if (root.speedTestPhase === "error") return "• " + (root.speedTestError.length > 0 ? root.speedTestError : "Erro no teste")
                                        return ""
                                    }
                                    color: root.speedTestPhase === "done"
                                           ? root.theme.green
                                           : (root.speedTestPhase === "error" ? root.theme.red : root.theme.primary)
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacingTokens.md

                                // Retest / Start
                                Rectangle {
                                    height: 18
                                    width: 20
                                    radius: root.theme.radiusXs
                                    color: retestHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.22) : "transparent"
                                    visible: !root.speedTestRunning

                                    TablerIcon {
                                        anchors.centerIn: parent
                                        width: root.theme.iconTokens.smPlus
                                        height: root.theme.iconTokens.smPlus
                                        iconName: "dashboard-refresh"
                                        iconColor: root.theme.primary
                                    }

                                    HoverHandler { id: retestHover }
                                    TapHandler {
                                        onTapped: root.startSpeedTest()
                                    }
                                }

                                // Stop
                                Rectangle {
                                    height: 18
                                    width: 20
                                    radius: root.theme.radiusXs
                                    color: stopHover.hovered ? root.theme.withAlpha(root.theme.red, 0.25) : "transparent"
                                    visible: root.speedTestRunning

                                    TablerIcon {
                                        anchors.centerIn: parent
                                        width: root.theme.iconTokens.smPlus
                                        height: root.theme.iconTokens.smPlus
                                        iconName: "network-stop"
                                        iconColor: root.theme.red
                                    }

                                    HoverHandler { id: stopHover }
                                    TapHandler {
                                        onTapped: root.stopSpeedTest()
                                    }
                                }

                                // Close
                                CloseButton {
                                    theme: root.theme
                                    buttonSize: 24
                                    onClicked: {
                                        root.stopSpeedTest()
                                        root.showSpeedTest = false
                                    }
                                }
                            }
                        }

                        // 3 Metric Boxes: Ping, Download, Upload
                        Row {
                            width: parent.width
                            height: 48
                            spacing: root.theme.spacingTokens.md

                            // Ping Box
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: parent.height
                                color: "transparent"
                                border.width: 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: root.theme.spacingTokens.tiny

                                    Row {
                                        spacing: root.theme.spacingTokens.xs
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        TablerIcon {
                                            width: root.theme.iconTokens.sm
                                            height: root.theme.iconTokens.sm
                                            iconName: "network-speedometer"
                                            iconColor: root.speedTestPing > 0 && root.speedTestPing < 60 ? root.theme.green : root.theme.yellow
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Latência"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.speedTestPing > 0 ? (root.speedTestPing + " ms") : "--"
                                        color: root.theme.foreground
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.subtitle
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Download Box
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: parent.height
                                color: "transparent"
                                border.width: 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: root.theme.spacingTokens.tiny

                                    Row {
                                        spacing: root.theme.spacingTokens.xs
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        TablerIcon {
                                            width: root.theme.iconTokens.sm
                                            height: root.theme.iconTokens.sm
                                            iconName: "dashboard-arrow-down"
                                            iconColor: root.theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Download"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.speedTestDown > 0 ? (root.speedTestDown + " Mbps") : (root.speedTestPhase === "download" ? "…" : "--")
                                        color: root.theme.primary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.subtitle
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Upload Box
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: parent.height
                                color: "transparent"
                                border.width: 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: root.theme.spacingTokens.tiny

                                    Row {
                                        spacing: root.theme.spacingTokens.xs
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        TablerIcon {
                                            width: root.theme.iconTokens.sm
                                            height: root.theme.iconTokens.sm
                                            iconName: "dashboard-arrow-up"
                                            iconColor: root.theme.secondary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Upload"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.speedTestUp > 0 ? (root.speedTestUp + " Mbps") : (root.speedTestPhase === "upload" ? "…" : "--")
                                        color: root.theme.secondary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.subtitle
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        // Progress bar
                        Rectangle {
                            width: parent.width
                            height: 3
                            radius: height / 2
                            color: root.theme.glassPanelSurface
                            clip: true

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, root.speedTestProgress))
                                height: parent.height
                                radius: parent.radius
                                color: root.speedTestPhase === "done" ? root.theme.green : root.theme.primary

                                Behavior on width {
                                    enabled: root.theme.qmlAnimationsEnabled
                                    NumberAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
                                }
                            }
                        }
                    }
                }

                // QR Code Inline Card
                Rectangle {
                    id: qrCard
                    visible: root.showQr && root.qrData !== null
                    width: parent.width
                    height: visible ? 108 : 0
                    radius: root.theme.radiusSm
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: root.theme.popupInsets.standard
                        spacing: root.theme.spacingTokens.xl

                        Rectangle {
                            width: 84
                            height: 84
                            radius: root.theme.radiusSm
                            color: root.theme.pureWhite

                            Image {
                                anchors.centerIn: parent
                                width: 80
                                height: 80
                                source: root.qrData ? ("file://" + root.qrData.path) : ""
                                fillMode: Image.PreserveAspectFit
                                cache: false
                            }
                        }

                        Column {
                            width: parent.width - 106
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.xs

                            Row {
                                width: parent.width
                                spacing: root.theme.spacingTokens.sm

                                Text {
                                    width: parent.width - 26
                                    text: root.qrData?.ssid ?? ""
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.subtitle
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                CloseButton {
                                    theme: root.theme
                                    buttonSize: 24
                                    onClicked: root.showQr = false
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: root.theme.spacingTokens.xsPlus

                                Text {
                                    width: parent.width - (passwordEye.visible ? passwordEye.width + parent.spacing : 0)
                                    text: root.qrData?.password
                                          ? ("Senha: " + (root.showQrPassword ? root.qrData.password : "••••••••"))
                                          : "Rede sem senha"
                                    color: root.theme.primary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                TablerIcon {
                                    id: passwordEye
                                    visible: Boolean(root.qrData?.password)
                                    width: visible ? root.theme.iconTokens.md : 0
                                    height: root.theme.iconTokens.md
                                    iconName: root.showQrPassword ? "network-eye" : "network-eye-off"
                                    iconColor: passwordEyeHover.hovered ? root.theme.primary : root.theme.surfaceVariantForeground

                                    HoverHandler { id: passwordEyeHover }
                                    TapHandler {
                                        onTapped: root.showQrPassword = !root.showQrPassword
                                    }
                                }
                            }

                            Text {
                                text: "Aponte a câmera para conectar"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.caption
                            }

                            Row {
                                spacing: root.theme.spacingTokens.sm
                                visible: Boolean(root.qrData?.password)

                                Rectangle {
                                    height: 20
                                    width: copyTxt.implicitWidth + 14
                                    radius: root.theme.radiusXs
                                    color: copyHover.hovered ? root.theme.primary : root.theme.withAlpha(root.theme.primary, 0.22)

                                    Text {
                                        id: copyTxt
                                        anchors.centerIn: parent
                                        text: "Copiar senha"
                                        color: copyHover.hovered ? root.theme.primaryForeground : root.theme.primary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.caption
                                        font.weight: Font.Bold
                                    }

                                    HoverHandler { id: copyHover }
                                    TapHandler {
                                        onTapped: {
                                            if (root.qrData?.password) {
                                                root.copyRequested(root.qrData.password)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Put VPN profiles before the potentially long Wi-Fi list so
                // their switches stay reachable without scrolling past APs.
                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.theme.outlineVariant
                    visible: root.vpns.length > 0
                }

                Column {
                    id: vpnSection
                    width: parent.width
                    spacing: root.theme.spacingTokens.sm
                    visible: root.vpns.length > 0

                    Item {
                        id: vpnHeader
                        width: parent.width
                        height: 20

                        Text {
                            text: "VPN"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.vpns

                            delegate: PopupListRow {
                                id: vpnDelegate
                                required property var modelData
                                theme: root.theme
                                active: Boolean(modelData.active)

                                readonly property string rowKey: "vpn:" + String(modelData.uuid)
                                readonly property bool isRowBusy: root.busyTarget === rowKey
                                readonly property bool isRowError: root.errorTarget === rowKey && root.errorText.length > 0

                                width: parent.width
                                rowHeight: isRowError ? 52 : 44

                                SettingToggleRow {
                                    anchors.fill: parent
                                    theme: root.theme
                                    showSurface: false
                                    rowHeight: parent.height
                                    tablerIcon: vpnDelegate.modelData.type === "wireguard"
                                        ? "network-shield" : "bar-lock"
                                    iconColor: vpnDelegate.modelData.active ? root.theme.primary : root.theme.foreground
                                    title: String(vpnDelegate.modelData.name)
                                    titleColor: root.theme.foreground
                                    titleWeight: vpnDelegate.modelData.active ? Font.Bold : Font.DemiBold
                                    description: vpnDelegate.isRowBusy
                                                 ? (vpnDelegate.modelData.active ? "Desconectando…" : "Conectando…")
                                                 : (vpnDelegate.isRowError
                                                    ? root.errorText
                                                    : (vpnDelegate.modelData.active
                                                       ? "Ativa"
                                                       : (vpnDelegate.modelData.type === "wireguard" ? "WireGuard" : "VPN")))
                                    descriptionColor: vpnDelegate.isRowError
                                                      ? root.theme.red
                                                      : (vpnDelegate.isRowBusy || vpnDelegate.modelData.active
                                                         ? root.theme.primary
                                                         : root.theme.foreground)
                                    descriptionPixelSize: root.theme.typeTokens.caption
                                    checked: Boolean(vpnDelegate.modelData.active)
                                    accessibleLabel: "VPN " + String(vpnDelegate.modelData.name ?? "")
                                    onToggleRequested: root.vpnToggleRequested(
                                        String(vpnDelegate.modelData.uuid), checked
                                    )
                                }
                            }
                        }
                    }
                }

                // Wi-Fi Section
                Column {
                    id: wifiSection
                    width: parent.width
                    spacing: root.theme.spacingTokens.sm

                    // Section Header: "REDES WI‑FI" + Escanear + Desconectar
                    Item {
                        id: wifiHeader
                        width: parent.width
                        height: 20

                        Text {
                            text: "REDES WI‑FI"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.xl

                            // Scan button
                            Row {
                                spacing: root.theme.spacingTokens.xs
                                visible: root.wifiEnabled
                                anchors.verticalCenter: parent.verticalCenter

                                TablerIcon {
                                    width: root.theme.iconTokens.sm
                                    height: root.theme.iconTokens.sm
                                    iconName: "dashboard-refresh"
                                    iconColor: refreshHover.hovered ? root.theme.primary : root.theme.surfaceVariantForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.wifiScanLoading ? "Buscando…" : "Buscar redes"
                                    color: refreshHover.hovered ? root.theme.primary : root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                HoverHandler { id: refreshHover }
                                TapHandler {
                                    enabled: !root.wifiScanLoading
                                    onTapped: root.refreshRequested()
                                }
                            }

                            // Disconnect button
                            Text {
                                visible: root.activeSsid.length > 0
                                text: "Desconectar"
                                color: disconnectHover.hovered ? root.theme.red : root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter

                                HoverHandler { id: disconnectHover }
                                TapHandler {
                                    onTapped: {
                                        if (root.activeDevice.length > 0)
                                            root.disconnectRequested(root.activeDevice)
                                    }
                                }
                            }
                        }
                    }

                    // Disabled state message
                    Item {
                        visible: root.wifiStateReady && !root.wifiEnabled
                        width: parent.width
                        height: 48

                        Row {
                            anchors.centerIn: parent
                            spacing: root.theme.spacingTokens.md

                            TablerIcon {
                                width: root.theme.iconTokens.lg
                                height: root.theme.iconTokens.lg
                                iconName: "bar-wifi-zero"
                                iconColor: root.theme.surfaceVariantForeground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Ative o Wi‑Fi para procurar redes"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.body
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Keep scan latency from looking like an empty result.
                    Item {
                        visible: root.wifiStateReady && root.wifiEnabled
                                 && root.wifiScanLoading && root.networks.length === 0
                        width: parent.width
                        height: 48

                        EmptyState {
                            anchors.fill: parent
                            theme: root.theme
                            horizontal: true
                            tablerIcon: "dashboard-refresh"
                            title: "Procurando redes Wi‑Fi…"
                            iconSize: root.theme.iconTokens.lg
                            titleSize: root.theme.typeTokens.body
                            iconColor: root.theme.primary
                            titleColor: root.theme.foreground
                            itemSpacing: root.theme.spacingTokens.md
                        }
                    }

                    // Empty networks message
                    Item {
                        visible: root.wifiStateReady && root.wifiEnabled
                                 && !root.wifiScanLoading && root.networks.length === 0
                        width: parent.width
                        height: 48

                        EmptyState {
                            anchors.fill: parent
                            theme: root.theme
                            horizontal: true
                            tablerIcon: "bar-wifi-zero"
                            title: "Nenhuma rede encontrada"
                            iconSize: root.theme.iconTokens.lg
                            titleSize: root.theme.typeTokens.body
                            iconColor: root.theme.foreground
                            titleColor: root.theme.foreground
                            itemSpacing: root.theme.spacingTokens.md
                        }
                    }

                    Rectangle {
                        visible: root.wifiEnabled && (root.networks.length >= 4 || wifiSearch.text.length > 0)
                        width: parent.width
                        height: visible ? 36 : 0
                        radius: root.theme.radiusMd
                        color: root.theme.surfaceContainer
                        border.width: 1
                        border.color: wifiSearch.activeFocus ? root.theme.primary : root.theme.borderSubtle

                        TablerIcon {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: root.theme.popupInsets.compact
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.theme.iconTokens.lg
                            height: root.theme.iconTokens.lg
                            iconName: "search"
                            iconColor: root.theme.surfaceVariantForeground
                        }

                        SearchField {
                            id: wifiSearch
                            theme: root.theme
                            anchors.left: searchIcon.right
                            anchors.right: clearSearch.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: root.theme.spacingTokens.md
                            anchors.rightMargin: root.theme.spacingTokens.sm
                            placeholderText: "Buscar rede…"
                            placeholderColor: root.theme.surfaceVariantForeground
                            color: root.theme.surfaceForeground
                            selectionColor: root.theme.primary
                            selectedTextColor: root.theme.primaryForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.bodyEmphasis
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            Accessible.name: "Buscar rede Wi-Fi"
                            debounceInterval: 120
                            onQueryChanged: function(query) { root.wifiFilter = query }
                        }

                        CloseButton {
                            id: clearSearch
                            theme: root.theme
                            buttonSize: 24
                            anchors.right: parent.right
                            anchors.rightMargin: root.theme.spacingTokens.sm
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wifiSearch.text.length > 0
                            accessibleLabel: "Limpar busca"
                            onClicked: {
                                wifiSearch.clear()
                                wifiSearch.forceActiveFocus()
                            }
                        }
                    }

                    EmptyState {
                        visible: root.wifiEnabled
                                 && root.networks.length > 0
                                 && root.filteredNetworks.length === 0
                        width: parent.width
                        height: 40
                        theme: root.theme
                        title: "Nenhuma rede corresponde à busca"
                        titleSize: root.theme.typeTokens.body
                    }

                    // Networks Repeater
                    Column {
                        visible: root.wifiEnabled && root.filteredNetworks.length > 0
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.filteredNetworks

                            delegate: PopupListRow {
                                id: wifiRow
                                required property var modelData
                                theme: root.theme
                                active: Boolean(modelData.active)
                                activeBorderColor: root.theme.borderSubtle

                                readonly property string rowKey: "wifi:" + String(modelData.ssid)
                                readonly property bool isRowBusy: root.busyTarget === rowKey
                                readonly property bool isRowError: root.errorTarget === rowKey && root.errorText.length > 0
                                // Key-action hit area (single source; the key
                                // item itself lives inside the trailing
                                // Component, whose ids are invisible here).
                                readonly property int keyActionSize: 26
                                readonly property bool hasKeyAction: Boolean(modelData.saved)
                                                                     && Boolean(modelData.secure)
                                                                     && !Boolean(modelData.active)

                                width: parent.width
                                leadingTablerIcon: root.wifiIcon(wifiRow.modelData.signal)
                                leadingIconColor: wifiRow.modelData.active ? root.theme.primary : root.theme.offWhite
                                leadingIconPixelSize: root.theme.iconTokens.xl
                                title: String(wifiRow.modelData.ssid)
                                titleWeight: wifiRow.modelData.active ? Font.Bold : Font.DemiBold
                                subtitle: wifiRow.isRowBusy
                                    ? (wifiRow.modelData.active ? "Desconectando…" : "Conectando…")
                                    : (wifiRow.isRowError
                                        ? root.errorText
                                        : (wifiRow.modelData.active
                                            ? "Conectado"
                                            : (wifiRow.modelData.saved
                                                ? "Rede salva"
                                                : (wifiRow.modelData.secure ? "Senha necessária" : "Rede aberta"))))
                                subtitleColor: wifiRow.isRowError
                                    ? root.theme.red
                                    : (wifiRow.isRowBusy
                                        ? root.theme.primary
                                        : (wifiRow.modelData.active ? root.theme.primary : root.theme.foreground))
                                trailing: Row {
                                    spacing: root.theme.spacingTokens.sm

                                    Text {
                                        text: Number(wifiRow.modelData.signal) + "%"
                                        color: root.theme.foreground
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.meta
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    TablerIcon {
                                        visible: Boolean(wifiRow.modelData.secure)
                                        width: root.theme.iconTokens.xs
                                        height: root.theme.iconTokens.xs
                                        iconName: "bar-lock"
                                        iconColor: root.theme.surfaceVariantForeground
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    // Saved networks keep connecting with the
                                    // stored secret; offer password re-entry.
                                    Item {
                                        visible: wifiRow.hasKeyAction
                                        width: visible ? wifiRow.keyActionSize : 0
                                        height: wifiRow.keyActionSize
                                        Accessible.name: "Trocar senha"

                                        TablerIcon {
                                            anchors.centerIn: parent
                                            width: root.theme.iconTokens.lg
                                            height: root.theme.iconTokens.lg
                                            iconName: "network-key"
                                            iconColor: keyHover.hovered ? root.theme.primary : root.theme.surfaceVariantForeground
                                        }

                                        HoverHandler { id: keyHover }
                                    }
                                }

                                // Tap handling must live in interactionHandlers:
                                // default content is hidden under the standard
                                // layout, so handlers placed there never fire.
                                // The key action hit-test uses delegate
                                // properties: ids inside the trailing
                                // Component are invisible from this scope.
                                interactionHandlers: TapHandler {
                                    enabled: !Boolean(wifiRow.modelData.active) && !wifiRow.isRowBusy
                                    onTapped: function(eventPoint) {
                                        if (wifiRow.hasKeyAction) {
                                            const ks = wifiRow.keyActionSize
                                            const kx = wifiRow.width - root.theme.popupInsets.compact - ks
                                            const ky = (wifiRow.rowHeight - ks) / 2
                                            const px = eventPoint.position.x
                                            const py = eventPoint.position.y
                                            if (px >= kx && px < kx + ks && py >= ky && py < ky + ks) {
                                                root.passwordPromptRequested(
                                                    String(wifiRow.modelData.ssid),
                                                    String(wifiRow.modelData.uuid ?? "")
                                                )
                                                return
                                            }
                                        }
                                        if (Boolean(wifiRow.modelData.saved) || !Boolean(wifiRow.modelData.secure)) {
                                            root.connectRequested(
                                                String(wifiRow.modelData.ssid),
                                                String(wifiRow.modelData.uuid ?? ""),
                                                Boolean(wifiRow.modelData.saved),
                                                Boolean(wifiRow.modelData.secure)
                                            )
                                        } else {
                                            root.passwordPromptRequested(String(wifiRow.modelData.ssid), "")
                                        }
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
