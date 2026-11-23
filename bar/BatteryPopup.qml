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
    readonly property string activeProfileId: String(root.profileData?.active ?? "")
    readonly property bool isExtraLowPower: root.activeProfileId === "extra-low-power"
    readonly property bool isEcoChargeLimit: Number(root.chargeLimitData?.limit) === 80

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.medium
    implicitHeight: mainColumn.implicitHeight + root.theme.popupInsets.large * 2
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    function timeText(sec) {
        if (!sec || sec <= 0) {
            return root.plugged ? "Completa" : "Calculando…"
        }
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + " min"
    }

    readonly property color levelColor:
        percentage <= 15 ? theme.red
        : percentage <= 35 ? theme.yellow
        : theme.green

    readonly property color headerAccent:
        root.charging ? root.theme.green
        : (root.isExtraLowPower && root.percentage > 15 ? root.theme.green : root.levelColor)

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
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.theme.popupInsets.large
            spacing: root.theme.spacingTokens.md

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 32
                leadingTablerIcon: root.charging ? "bolt" : (root.isExtraLowPower ? "leaf" : "battery")
                leadingIconColor: root.headerAccent
                iconBoxSize: 32
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.withAlpha(root.headerAccent, 0.14)
                iconPixelSize: root.theme.iconTokens.lgPlus
                title: "Bateria"
                subtitle: root.stateText + (root.isExtraLowPower ? " · Ultra Eco" : "")
                subtitleColor: root.isExtraLowPower && !root.charging
                    ? root.theme.green : root.theme.surfaceVariantForeground
                subtitlePixelSize: root.theme.typeTokens.meta
                titlePixelSize: root.theme.typeTokens.title
                titleWeight: Font.DemiBold
                actionSpacing: 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.percentage) + "%"
                    color: root.levelColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.display
                    font.weight: Font.Bold
                }
            }

            // Barra de nível com marca sutil de 80% quando Eco 80% está ativo
            Item {
                width: parent.width
                height: 8

                Rectangle {
                    id: chargeTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
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

                Rectangle {
                    visible: root.chargeLimitVisible && root.isEcoChargeLimit
                    x: Math.round(chargeTrack.width * 0.80) - 1
                    anchors.verticalCenter: chargeTrack.verticalCenter
                    width: 2
                    height: 10
                    radius: 1
                    color: root.theme.surfaceForeground
                    opacity: 0.65
                }
            }

            // Métricas: Tempo | Consumo / Potência | Saúde (quando disponível)
            Row {
                width: parent.width
                spacing: root.theme.spacingTokens.sm

                readonly property int cardCount: root.healthVisible ? 3 : 2
                readonly property real cardWidth:
                    (width - spacing * (cardCount - 1)) / cardCount

                Rectangle {
                    width: parent.cardWidth
                    height: 54
                    radius: root.theme.radiusMd
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.theme.popupInsets.compact
                        spacing: root.theme.spacingTokens.xs

                        Row {
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                width: root.theme.iconTokens.smPlus
                                height: root.theme.iconTokens.smPlus
                                iconName: "clock"
                                iconColor: root.theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.charging ? "Até 100%" : "Restante"
                                color: root.theme.surfaceVariantForeground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.timeText(root.secondsRemaining)
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.bodyEmphasis
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.cardWidth
                    height: 54
                    radius: root.theme.radiusMd
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.theme.popupInsets.compact
                        spacing: root.theme.spacingTokens.xs

                        Row {
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                width: root.theme.iconTokens.smPlus
                                height: root.theme.iconTokens.smPlus
                                iconName: "bolt"
                                iconColor: root.theme.cyan
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.charging ? "Potência" : "Consumo"
                                color: root.theme.surfaceVariantForeground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.watts > 0 ? (root.watts.toFixed(1) + " W") : "0.0 W"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.bodyEmphasis
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    visible: root.healthVisible
                    width: visible ? parent.cardWidth : 0
                    height: 54
                    radius: root.theme.radiusMd
                    color: root.theme.adaptiveCardSurface
                    border.width: 1
                    border.color: root.theme.adaptiveCardBorder

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.theme.popupInsets.compact
                        spacing: root.theme.spacingTokens.xs

                        Row {
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                width: root.theme.iconTokens.smPlus
                                height: root.theme.iconTokens.smPlus
                                iconName: "network-shield"
                                iconColor: root.theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Saúde"
                                color: root.theme.surfaceVariantForeground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            text: Math.round(Math.max(0, Math.min(100, root.healthPercentage))) + "%"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.bodyEmphasis
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Card de controles de energia e carga
            Rectangle {
                width: parent.width
                height: controlsColumn.implicitHeight + root.theme.popupInsets.standard * 2
                radius: root.theme.radiusLg
                color: root.theme.adaptiveCardSurface
                border.width: 1
                border.color: root.theme.adaptiveCardBorder

                Column {
                    id: controlsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.theme.popupInsets.standard
                    spacing: root.theme.spacingTokens.md

                    // Perfil de energia
                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.sm

                        Row {
                            width: parent.width

                            Text {
                                id: profileHeading
                                text: "Perfil de energia"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.body
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: Math.max(0, parent.width - profileHeading.implicitWidth - profileBadge.width)
                                height: 1
                            }

                            Rectangle {
                                id: profileBadge
                                visible: profileBadgeText.text.length > 0
                                width: profileBadgeText.implicitWidth + 12
                                height: 18
                                radius: height / 2
                                color: root.isExtraLowPower
                                       ? root.theme.withAlpha(root.theme.green, 0.16)
                                       : root.theme.glassCardSurface
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: profileBadgeText
                                    anchors.centerIn: parent
                                    text: root.isExtraLowPower
                                          ? (Boolean(root.profileData?.auto_activated) ? "≤ 15% auto" : "1,6 GHz")
                                          : String(root.profileData?.backend_label ?? "")
                                    color: root.isExtraLowPower
                                           ? root.theme.green : root.theme.surfaceVariantForeground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.caption
                                    font.weight: root.isExtraLowPower ? Font.DemiBold : Font.Normal
                                }
                            }
                        }

                        PowerProfileSelector {
                            theme: root.theme
                            profiles: root.profileData?.profiles ?? []
                            activeProfile: root.activeProfileId
                            available: Boolean(root.profileData?.available ?? true)
                            busy: root.profileBusy
                            onProfileRequested: function(profileId) {
                                root.profileRequested(profileId)
                            }
                        }

                        Text {
                            visible: root.isExtraLowPower
                            width: parent.width
                            text: "Teto 1,6 GHz · Turbo desligado · Volta a Equilibrado na tomada"
                            color: root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.caption
                            wrapMode: Text.WordWrap
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

                    Rectangle {
                        visible: root.cpuBoostVisible
                        width: parent.width
                        height: 1
                        color: root.theme.borderSubtle
                    }

                    // Turbo do processador
                    Column {
                        visible: root.cpuBoostVisible
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        SettingToggleRow {
                            theme: root.theme
                            tablerIcon: "cpu"
                            title: "Turbo do processador"
                            description: root.isExtraLowPower && !Boolean(root.cpuBoostData?.enabled)
                                ? "Desativado automaticamente em Ultra Eco"
                                : "Permite frequências acima da base"
                            checked: Boolean(root.cpuBoostData?.enabled)
                            enabled: !root.cpuBoostBusy
                            rowHeight: 46
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

                    Rectangle {
                        visible: root.chargeLimitVisible
                        width: parent.width
                        height: 1
                        color: root.theme.borderSubtle
                    }

                    // Limite de carga (Eco 80% | Viagem 100%)
                    Column {
                        visible: root.chargeLimitVisible
                        width: parent.width
                        spacing: root.theme.spacingTokens.sm

                        Row {
                            width: parent.width

                            Text {
                                id: chargeLimitHeading
                                text: "Limite de carga"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.body
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: Math.max(0, parent.width - chargeLimitHeading.implicitWidth - chargeLimitBadge.width)
                                height: 1
                            }

                            Rectangle {
                                id: chargeLimitBadge
                                width: chargeLimitLabel.implicitWidth + 12
                                height: 18
                                radius: height / 2
                                color: root.isEcoChargeLimit
                                       ? root.theme.withAlpha(root.theme.green, 0.14)
                                       : root.theme.withAlpha(root.theme.yellow, 0.14)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: chargeLimitLabel
                                    anchors.centerIn: parent
                                    text: root.isEcoChargeLimit ? "Eco 80%" : "Viagem 100%"
                                    color: root.isEcoChargeLimit ? root.theme.green : root.theme.yellow
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.caption
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        PowerProfileSelector {
                            theme: root.theme
                            profiles: [
                                { id: "80", label: "Eco 80%", icon: "network-shield" },
                                { id: "100", label: "Viagem 100%", icon: "bolt" }
                            ]
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
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
