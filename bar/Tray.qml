pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray

Rectangle {
    id: root
    required property var theme
    required property var panelWindow
    property bool plain: false

    visible: trayRow.implicitWidth > 0
    implicitHeight: root.theme ? root.theme.pillHeight : 25
    implicitWidth: trayRow.implicitWidth + (root.plain ? 0 : root.theme.spacingTokens.xxl)
    radius: root.theme.pillRadius
    clip: true

    color: root.plain ? "transparent" : root.theme.pillBackground

    border.width: root.plain ? 0 : 1
    border.color: trayHover.hovered
           ? root.theme.pillBorderHover
           : root.theme.pillBorder

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.theme.stateLayer(
            root.theme.surfaceForeground,
            trayHover.hovered ? "hover" : "none"
        )
        Behavior on color {
            enabled: root.theme.qmlAnimationsEnabled
            ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
        }
    }

    Behavior on border.color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    HoverHandler {
        id: trayHover
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: root.theme.spacingTokens.xs

        Repeater {
            // Secret-agent / IME items stay running but are neither shown
            // nor icon-loaded here: an empty Image source keeps KIconLoader
            // away from nm-applet's animated theme icons, which caused a
            // past SIGSEGV (see ~/.cache/quickshell/crashes).
            model: SystemTray.items

            delegate: Item {
                                id: trayDelegate
                required property var modelData

                readonly property bool shown: modelData.id !== "fcitx5"
                         && modelData.id !== "nm-applet"
                         && modelData.id !== "network-manager-applet"
                         && modelData.id !== "spotify-client"
                         && modelData.id !== "chrome_status_icon_1"
                visible: shown
                width: shown ? root.theme.barTrayItemWidth : 0
                height: root.theme.pillHeight

                Image {
                    id: trayIconSource
                    anchors.centerIn: parent
                    width: root.theme.barTrayIconSize
                    height: root.theme.barTrayIconSize
                    source: trayDelegate.shown ? trayDelegate.modelData.icon : ""
                    sourceSize.width: root.theme.barTrayIconSize
                    sourceSize.height: root.theme.barTrayIconSize
                    visible: !root.theme.isLight
                }

                MultiEffect {
                    anchors.centerIn: parent
                    width: root.theme.barTrayIconSize
                    height: root.theme.barTrayIconSize
                    source: trayIconSource
                    visible: trayDelegate.shown && root.theme.isLight
                    colorization: 1.0
                    colorizationColor: root.theme.foreground
                }

                TrayMenu {
                    id: trayMenu
                    theme: root.theme
                    target: trayDelegate
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            trayDelegate.modelData.secondaryActivate()
                            return
                        }

                        if (mouse.button === Qt.LeftButton && !trayDelegate.modelData.onlyMenu) {
                            trayDelegate.modelData.activate()
                            return
                        }

                        if (trayDelegate.modelData.hasMenu) {
                            if (trayMenu.visible) trayMenu.closeMenu()
                            else trayMenu.open(trayDelegate.modelData.menu)
                        }
                        else if (mouse.button === Qt.LeftButton)
                            trayDelegate.modelData.activate()
                    }

                    onWheel: function(wheel) {
                        trayDelegate.modelData.scroll(
                            wheel.angleDelta.y !== 0
                                ? wheel.angleDelta.y
                                : wheel.angleDelta.x,
                            wheel.angleDelta.x !== 0
                        )
                    }
                }
            }
        }
    }
}
