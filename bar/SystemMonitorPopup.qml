pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property real memoryUsedMb: 0
    property real memoryTotalMb: 0
    property int memoryPercent: 0
    property int cpuFrequencyMhz: 0
    property real temperature: 0
    property int fanRpm: 0
    property string fanSensor: ""
    property int fanPwmPercent: 0
    readonly property bool fanActive: fanRpm > 0 || fanPwmPercent > 0

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
    implicitHeight: 260
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    readonly property color temperatureColor:
        temperature >= 80 ? theme.red
        : temperature >= 70 ? theme.orange
        : temperature >= 60 ? theme.yellow
        : theme.cyan

    readonly property color memoryColor:
        memoryPercent >= 90 ? theme.red
        : memoryPercent >= 75 ? theme.yellow
        : theme.accent

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
            spacing: root.theme.spacingTokens.sm

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 30
                horizontalInset: 0
                topInset: 0
                iconBoxSize: 26
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lg
                leadingTablerIcon: "device-desktop"
                leadingIconColor: root.theme.accent
                title: "Monitor do sistema"
                titlePixelSize: root.theme.typeTokens.subtitle
                titleWeight: Font.DemiBold
                contentGap: root.theme.spacingTokens.sm
                actionSpacing: 0
            }

            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                PopupListRow {
                    theme: root.theme
                    rowHeight: 48
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: false
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    leadingTablerIcon: "cpu"
                    leadingIconColor: root.theme.primary
                    leadingIconPixelSize: root.theme.iconTokens.lg
                    title: "Processador"
                    subtitle: "Frequência média"
                    subtitleColor: root.theme.surfaceVariantForeground

                    trailing: Component {
                        Text {
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            text: root.cpuFrequencyMhz > 0 ? root.cpuFrequencyMhz + " MHz" : "—"
                            color: root.cpuFrequencyMhz > 0 ? root.theme.foreground : root.theme.grey
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                        }
                    }
                }

                PopupListRow {
                    theme: root.theme
                    rowHeight: 48
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: false
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    leadingTablerIcon: "memory"
                    leadingIconColor: root.theme.primary
                    leadingIconPixelSize: root.theme.iconTokens.lg
                    title: "Memória"
                    subtitle: root.memoryTotalMb > 0
                        ? (root.memoryUsedMb / 1024).toFixed(1).replace(".", ",")
                          + " / " + (root.memoryTotalMb / 1024).toFixed(1).replace(".", ",") + " GiB"
                        : "Indisponível"
                    subtitleColor: root.theme.surfaceVariantForeground
                    topDivider: true

                    trailing: Component {
                        Column {
                            width: 68
                            spacing: root.theme.spacingTokens.micro
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                            Text {
                                width: parent.width
                                text: root.memoryTotalMb > 0 ? root.memoryPercent + "%" : "—"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                width: parent.width
                                height: root.theme.spacingTokens.tight
                                radius: root.theme.radiusSm
                                color: root.theme.sliderTrack
                                clip: true

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, root.memoryPercent / 100))
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.memoryColor
                                }
                            }
                        }
                    }
                }

                PopupListRow {
                    theme: root.theme
                    rowHeight: 48
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: false
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    leadingTablerIcon: "dashboard-thermometer"
                    leadingIconColor: root.temperature > 0 ? root.temperatureColor : root.theme.grey
                    leadingIconPixelSize: root.theme.iconTokens.lg
                    title: "Temperatura"
                    subtitle: "Processador"
                    subtitleColor: root.theme.surfaceVariantForeground
                    topDivider: true

                    trailing: Component {
                        Column {
                            width: 68
                            spacing: root.theme.spacingTokens.micro
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                            Text {
                                width: parent.width
                                text: root.temperature > 0 ? Math.round(root.temperature) + "°C" : "—"
                                color: root.temperature > 0 ? root.temperatureColor : root.theme.grey
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                width: parent.width
                                height: root.theme.spacingTokens.tight
                                radius: root.theme.radiusSm
                                color: root.theme.sliderTrack
                                clip: true
                                visible: root.temperature > 0

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, root.temperature / 100))
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.temperatureColor
                                }
                            }
                        }
                    }
                }

                PopupListRow {
                    theme: root.theme
                    rowHeight: 42
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: false
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    leadingTablerIcon: "fan"
                    leadingIconColor: root.fanSensor === "unavailable"
                        ? root.theme.grey
                        : (root.fanActive ? root.theme.cyan : root.theme.grey)
                    leadingIconPixelSize: root.theme.iconTokens.lg
                    title: "Ventoinha"
                    subtitle: root.fanSensor === "unavailable"
                        ? "Sensor indisponível"
                        : (root.fanRpm > 0
                           ? root.fanSensor
                           : (root.fanPwmPercent > 0
                              ? "Acionada pelo controlador"
                              : "0 RPM · parada"))
                    subtitleColor: root.fanSensor === "unavailable" || !root.fanActive
                        ? root.theme.surfaceVariantForeground
                        : root.theme.foreground
                    topDivider: true

                    trailing: Component {
                        Row {
                            spacing: root.theme.spacingTokens.xs
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fanSensor === "unavailable"
                                    ? "N/D"
                                    : (root.fanRpm > 0
                                       ? root.fanRpm + " RPM"
                                       : (root.fanPwmPercent > 0
                                          ? root.fanPwmPercent + "% PWM"
                                          : "0 RPM"))
                                color: root.fanSensor === "unavailable" || !root.fanActive
                                    ? root.theme.grey
                                    : root.theme.cyan
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                                font.weight: Font.DemiBold
                            }

                            TablerIcon {
                                width: root.theme.iconTokens.md
                                height: root.theme.iconTokens.md
                                iconName: "fan"
                                iconColor: root.fanSensor === "unavailable" || !root.fanActive
                                    ? root.theme.surfaceVariantForeground : root.theme.cyan
                                anchors.verticalCenter: parent.verticalCenter
                                NumberAnimation on rotation {
                                    running: root.visible && root.theme.qmlAnimationsEnabled && root.fanActive
                                    from: 0
                                    to: 360
                                    loops: Animation.Infinite
                                    duration: root.fanRpm > 0
                                        ? Math.max(300, Math.min(2500,
                                            Math.round(180000 / Math.max(500, root.fanRpm))))
                                        : 1200
                                }
                            }
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
