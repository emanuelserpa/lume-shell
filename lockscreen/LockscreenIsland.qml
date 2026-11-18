pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.bar
import qs.components

Item {
    id: root

    required property var theme
    readonly property real contentScale: 1.22
    property bool suspendMenuOpen: false

    implicitWidth: island.implicitWidth
    implicitHeight: island.height

    onSuspendMenuOpenChanged: {
        if (suspendMenuOpen)
            suspendAction.forceActiveFocus()
        else
            powerTarget.forceActiveFocus()
    }

    Rectangle {
        id: island
        anchors.fill: parent
        implicitWidth: content.implicitWidth + 28
        height: 52
        radius: height / 2
        color: root.theme.glassPanelSurface
        border.width: 1
        border.color: root.theme.glassBorderSubtle

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: batteryPill.implicitWidth * root.contentScale
                height: root.theme.pillHeight * root.contentScale

                Battery {
                    id: batteryPill
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    transform: Scale {
                        origin.x: batteryPill.width / 2
                        origin.y: batteryPill.height / 2
                        xScale: root.contentScale
                        yScale: root.contentScale
                    }
                    theme: root.theme
                    plain: true
                }
            }

            Item {
                id: audioHitArea
                width: audioPill.implicitWidth * root.contentScale
                height: root.theme.pillHeight * root.contentScale

                Audio {
                    id: audioPill
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    transform: Scale {
                        origin.x: audioPill.width / 2
                        origin.y: audioPill.height / 2
                        xScale: root.contentScale
                        yScale: root.contentScale
                    }
                    theme: root.theme
                    plain: true
                    interactive: false
                    allowExternalSettings: false
                    popupTarget: audioHitArea
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            audioPill.openPopup()
                        } else if (mouse.button === Qt.RightButton && audioPill.sink?.audio) {
                            audioPill.sink.audio.muted = !audioPill.sink.audio.muted
                        }
                    }

                    onWheel: function(wheel) {
                        wheel.accepted = true
                        if (!audioPill.sink?.audio || audioPill.sink.audio.muted)
                            return
                        const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                        audioPill.sink.audio.volume = Math.max(0, Math.min(1.5,
                            audioPill.sink.audio.volume + delta))
                    }
                }
            }

            Item {
                id: powerTarget
                width: root.theme.pillHeight * root.contentScale
                height: root.theme.pillHeight * root.contentScale
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Abrir opções de energia"

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: powerHover.hovered || powerTarget.activeFocus
                           ? root.theme.glassHoverSurface : "transparent"
                    border.width: powerTarget.activeFocus ? 1 : 0
                    border.color: root.theme.glassBorder
                }

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.barIconSize * root.contentScale
                    height: root.theme.barIconSize * root.contentScale
                    iconName: "power"
                    iconColor: root.theme.foreground
                }

                HoverHandler {
                    id: powerHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.suspendMenuOpen = !root.suspendMenuOpen
                }

                Keys.onReturnPressed: root.suspendMenuOpen = !root.suspendMenuOpen
                Keys.onEnterPressed: root.suspendMenuOpen = !root.suspendMenuOpen
                Keys.onSpacePressed: root.suspendMenuOpen = !root.suspendMenuOpen

                ToolTipBubble {
                    theme: root.theme
                    target: powerTarget
                    text: "Opções de energia"
                    requestedVisible: powerHover.hovered && !root.suspendMenuOpen
                }
            }
        }
    }

    PopupCard {
        id: suspendMenu
        theme: root.theme
        opened: root.suspendMenuOpen
        width: 190
        height: 72
        anchors.top: island.bottom
        anchors.right: island.right
        anchors.topMargin: root.theme.popupInsets.small
        z: 10
        visible: root.suspendMenuOpen

        Keys.onEscapePressed: root.suspendMenuOpen = false

        Rectangle {
            id: suspendAction
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.compact
            radius: root.theme.radiusMd
            color: suspendHover.hovered || suspendAction.activeFocus
                   ? root.theme.glassHoverSurface : "transparent"
            border.width: suspendAction.activeFocus ? 1 : 0
            border.color: root.theme.glassBorder
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Suspender computador"

            Row {
                anchors.fill: parent
                anchors.leftMargin: root.theme.popupInsets.standard
                anchors.rightMargin: root.theme.popupInsets.standard
                spacing: root.theme.spacingTokens.md

                TablerIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    iconName: "bar-moon"
                    iconColor: root.theme.cyan
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Suspender"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                    font.weight: Font.DemiBold
                }
            }

            HoverHandler {
                id: suspendHover
                cursorShape: Qt.PointingHandCursor
            }

            function activate() {
                root.suspendMenuOpen = false
                Qt.callLater(function() {
                    Quickshell.execDetached([
                        "/usr/bin/bash",
                        Quickshell.shellDir + "/scripts/session-action.sh",
                        "suspend"
                    ])
                })
            }

            TapHandler { onTapped: suspendAction.activate() }
            Keys.onReturnPressed: suspendAction.activate()
            Keys.onEnterPressed: suspendAction.activate()
            Keys.onSpacePressed: suspendAction.activate()
        }
    }
}
