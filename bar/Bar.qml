import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// qmllint disable uncreatable-type
PanelWindow {
    // The compositor plugin provides the concrete PanelWindow implementation.
    // qmllint enable uncreatable-type
    id: root

    property var launcherController: null
    readonly property bool projectionOwner: {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase()
        if (desktop.includes("mango") && MangoState.focusedOutput.length > 0)
            // QuickshellScreenInfo exposes name at runtime; qmllint metadata omits it.
            // qmllint disable missing-property
            return root.screen.name === MangoState.focusedOutput
            // qmllint enable missing-property
        if (desktop.includes("hyprland")) {
            const monitor = Hyprland.monitorFor(root.screen)
            if (monitor !== null && monitor !== undefined)
                return Boolean(monitor.focused)
        }
        return Quickshell.screens.length === 0 || root.screen === Quickshell.screens[0]
    }
    anchors {
        top: true
        left: true
        right: true
    }

    IdleInhibitor {
        window: root
        enabled: IdleState.inhibited
    }

    implicitHeight: barTheme.barHeight
    color: "transparent"
    surfaceFormat.opaque: false
    exclusiveZone: barTheme.barHeight

    Theme { id: barTheme }

    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.margins: barTheme.barPanelInset
        color: "transparent"
        border.width: 0

        BarIslandSurface { theme: barTheme; target: leftIsland }
        BarIslandSurface { theme: barTheme; target: submapIslandSlot; visible: submapWidget.visible }
        BarIslandSurface { theme: barTheme; target: centerCluster }
        BarIslandSurface { theme: barTheme; target: mediaIslandSlot; visible: mediaIsland.visible }
        BarIslandSurface { theme: barTheme; target: statusIslandSlot; visible: statusIslandSlot.islandVisible }
        BarIslandSurface { theme: barTheme; target: rightIsland }

        Row {
            id: leftIsland
            anchors.left: parent.left
            anchors.leftMargin: barTheme.spacingTokens.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: barTheme.barIslandSpacing

            StartButton {
                theme: barTheme
                plain: true
                launcherController: root.launcherController
            }

            // Breathing room so workspace 1 is not hit by mistake.
            Item { width: barTheme.spacingTokens.xsPlus; height: 1 }

            Workspaces {
                theme: barTheme
                screen: root.screen
                plain: true
            }

        }

        Item {
            id: submapIslandSlot
            anchors.left: leftIsland.right
            anchors.leftMargin: barTheme.barIslandPadding * 2 + barTheme.spacingTokens.xs
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: submapWidget.visible ? submapWidget.implicitWidth : 0
            width: implicitWidth
            height: barTheme.barIslandHeight

            Submap {
                id: submapWidget
                theme: barTheme
                plain: true
                anchors.centerIn: parent
            }
        }

        Row {
            id: centerCluster
            anchors.centerIn: parent
            spacing: barTheme.spacingTokens.smPlus
            width: implicitWidth

            Weather {
                theme: barTheme
                plain: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                color: barTheme.grey
                opacity: 0.75
                font.family: barTheme.fontFamily
                font.pixelSize: barTheme.typeTokens.bodyEmphasis
            }

            Clock {
                theme: barTheme
                plain: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            id: statusIslandSlot
            readonly property int islandGap: barTheme.barIslandPadding * 2 + barTheme.spacingTokens.xs
            readonly property int availableSpan: Math.max(
                0,
                Math.floor(rightIsland.x - (centerCluster.x + centerCluster.width) - islandGap * 2)
            )
            readonly property bool islandVisible: statusIsland.hasActiveIndicators
                                                  && availableSpan >= statusIsland.implicitWidth
            anchors.right: rightIsland.left
            anchors.rightMargin: islandVisible ? islandGap : 0
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: islandVisible ? statusIsland.implicitWidth : 0
            width: implicitWidth
            height: barTheme.barIslandHeight
            visible: islandVisible

            StatusIsland {
                id: statusIsland
                anchors.centerIn: parent
                theme: barTheme
            }
        }

        Item {
            id: mediaIslandSlot
            readonly property int symmetricGap: barTheme.spacingTokens.md
            anchors.left: centerCluster.right
            anchors.right: statusIslandSlot.islandVisible ? statusIslandSlot.left : rightIsland.left
            anchors.leftMargin: symmetricGap
            anchors.rightMargin: statusIslandSlot.islandVisible ? statusIslandSlot.islandGap : symmetricGap
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: mediaIsland.implicitWidth
            implicitHeight: barTheme.barIslandHeight

            MediaIsland {
                id: mediaIsland
                anchors.centerIn: parent
                theme: barTheme
                visible: mediaIsland.spotifyPlayer !== null && parent.width >= implicitWidth
            }
        }

        Row {
            id: rightIsland
            anchors.right: parent.right
            anchors.rightMargin: barTheme.spacingTokens.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: barTheme.spacingTokens.xsPlus

            Tray {
                theme: barTheme
                panelWindow: root
                plain: true
            }

            Item {
                width: barTheme.spacingTokens.md
                height: 1
            }

            Network { theme: barTheme; plain: true }
            Bluetooth { theme: barTheme; plain: true }
            Printer { theme: barTheme; plain: true }
            SystemMonitor { theme: barTheme; plain: true }
            UpdateControl { theme: barTheme; plain: true }
            Battery { theme: barTheme; plain: true }
            Audio { theme: barTheme; plain: true }
            NotificationControl { theme: barTheme; plain: true }

        }

        DisplayProjectionPopup {
            theme: barTheme
            target: rightIsland
            ownerActive: root.projectionOwner
        }
    }
}
