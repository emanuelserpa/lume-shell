import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property real percentage: 0
    property bool charging: false
    property bool plugged: false
    property real watts: 0
    property real secondsRemaining: 0
    property bool healthAvailable: false
    property real healthPercentage: 0
    property string stateText: "Bateria"
    property var profileData: ({})
    property bool profileBusy: false
    property string profileError: ""
    property var cpuBoostData: ({})
    property bool cpuBoostBusy: false
    property string cpuBoostError: ""
    property var chargeLimitData: ({})
    property bool chargeLimitBusy: false
    property string chargeLimitError: ""

    signal profileRequested(string profile)
    signal cpuBoostRequested(bool enabled)
    signal chargeLimitRequested(string mode)

    readonly property bool chargeLimitVisible: root.chargeLimitData?.available !== false
    readonly property bool cpuBoostVisible: root.cpuBoostData?.available === true
    readonly property bool healthVisible:
        root.healthAvailable && Number.isFinite(root.healthPercentage) && root.healthPercentage > 0

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.small
    implicitHeight: (root.chargeLimitVisible ? 240 : 184)
                   + (root.cpuBoostVisible ? 54 + (root.cpuBoostError.length > 0 ? 14 : 0) : 0)
                   + (root.healthVisible ? 30 : 0)
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true


    function timeText(sec) {
        if (!sec || sec <= 0) {
            return root.plugged ? "Completa" : "Calculando..."
        }
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + " min"
    }

    readonly property color levelColor:
        percentage <= 15 ? theme.red
        : percentage <= 35 ? theme.yellow
        : theme.green

    onVisibleChanged: {
        if (visible)
            card.forceActiveFocus()
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        Keys.onEscapePressed: root.visible = false

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.standard
            spacing: root.theme.spacingTokens.md

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 28
                leadingTablerIcon: "battery"
                leadingIconColor: root.levelColor
                iconBoxSize: 28
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lgPlus
                title: "Bateria"
                subtitle: root.stateText
                subtitleColor: root.theme.surfaceVariantForeground
                subtitlePixelSize: root.theme.typeTokens.meta
                titlePixelSize: root.theme.typeTokens.subtitle
                titleWeight: Font.DemiBold
                actionSpacing: 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.percentage) + "%"
                    color: root.levelColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.metricLarge
                    font.weight: Font.Bold
                }
            }

            // Barra fina de progresso
            Rectangle {
                width: parent.width
                height: 4
                radius: height / 2
                color: root.theme.sliderTrack
                clip: true

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.percentage / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.levelColor
                }
            }

            // Métricas: Tempo Restante | Consumo / Potência
            Row {
                width: parent.width
                spacing: root.theme.spacingTokens.sm

                Rectangle {
                    width: (parent.width - 6) / 2
                    height: 46
                    radius: root.theme.radiusMd
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Row {
                        anchors.centerIn: parent
                        spacing: root.theme.spacingTokens.sm

                        TablerIcon {
                            width: root.theme.iconTokens.mdPlus
                            height: root.theme.iconTokens.mdPlus
                            iconName: "clock"
                            iconColor: root.theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.micro

                            Text {
                                text: root.charging ? "Até 100%" : "Restante"
                                color: root.theme.surfaceVariantForeground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.caption
                            }

                            Text {
                                text: root.timeText(root.secondsRemaining)
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.subtitle
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 6) / 2
                    height: 46
                    radius: root.theme.radiusMd
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Row {
                        anchors.centerIn: parent
                        spacing: root.theme.spacingTokens.sm

                        TablerIcon {
                            width: root.theme.iconTokens.mdPlus
                            height: root.theme.iconTokens.mdPlus
                            iconName: "bolt"
                            iconColor: root.theme.cyan
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: root.theme.spacingTokens.micro
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: root.charging ? "Potência" : "Consumo"
                                color: root.theme.surfaceVariantForeground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.caption
                            }

                            Text {
                                text: root.watts > 0 ? (root.watts.toFixed(1) + " W") : "0.0 W"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.subtitle
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.healthVisible
                width: parent.width
                height: visible ? 18 : 0

                Text {
                    text: "Saúde estimada"
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                }

                Text {
                    text: Math.round(Math.max(0, Math.min(100, root.healthPercentage))) + "% da capacidade original"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
            }

            // Perfil de energia (Economia | Balanceado | Desempenho)
            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xsPlus

                Row {
                    width: parent.width

                    Text {
                        text: "Perfil de energia"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: Math.max(0, parent.width - 170); height: 1 }

                    Text {
                        text: String(root.profileData?.backend_label ?? "")
                        color: root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                PowerProfileSelector {
                    theme: root.theme
                    profiles: root.profileData?.profiles ?? []
                    activeProfile: String(root.profileData?.active ?? "")
                    available: Boolean(root.profileData?.available ?? true)
                    busy: root.profileBusy
                    onProfileRequested: function(profileId) {
                        root.profileRequested(profileId)
                    }
                }

                Text {
                    visible: root.profileError.length > 0
                    width: parent.width
                    text: root.profileError
                    color: root.theme.red
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    elide: Text.ElideRight
                }
            }

            Column {
                visible: root.cpuBoostVisible
                width: parent.width
                spacing: root.theme.spacingTokens.xsPlus

                SettingToggleRow {
                    theme: root.theme
                    tablerIcon: "cpu"
                    title: "Turbo do processador"
                    description: "Permite frequências acima da base"
                    checked: Boolean(root.cpuBoostData?.enabled)
                    enabled: !root.cpuBoostBusy
                    rowHeight: 48
                    iconColor: root.theme.primary
                    accessibleLabel: "Ativar turbo do processador"
                    onToggleRequested: function(enabled) {
                        root.cpuBoostRequested(enabled)
                    }
                }

                Text {
                    visible: root.cpuBoostError.length > 0
                    width: parent.width
                    text: root.cpuBoostError
                    color: root.theme.red
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    elide: Text.ElideRight
                }
            }

            // Limite de carga (Eco 80% | Viagem 100%)
            Column {
                visible: root.chargeLimitVisible
                width: parent.width
                spacing: root.theme.spacingTokens.xsPlus

                Row {
                    width: parent.width

                    Text {
                        text: "Limite de carga"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: Math.max(0, parent.width - 195); height: 1 }

                    Text {
                        text: Number(root.chargeLimitData?.limit) === 100 ? "Viagem 100%" : "Eco 80%"
                        color: root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                PowerProfileSelector {
                    theme: root.theme
                    profiles: [{ id: "80", label: "Eco 80%" }, { id: "100", label: "Viagem 100%" }]
                    activeProfile: String(root.chargeLimitData?.limit ?? "")
                    available: Boolean(root.chargeLimitData?.available ?? true)
                    busy: root.chargeLimitBusy
                    onProfileRequested: function(mode) {
                        root.chargeLimitRequested(mode)
                    }
                }

                Text {
                    visible: root.chargeLimitError.length > 0
                    width: parent.width
                    text: root.chargeLimitError
                    color: root.theme.red
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    elide: Text.ElideRight
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
