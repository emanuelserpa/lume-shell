import QtQuick
import qs.components

Rectangle {
    id: root

    required property var theme
    property string icon: "󰏗"
    property string tablerIcon: ""
    property string title: "Backend"
    property string subtitle: ""
    property color accentColor: theme.accent
    property string statusText: "0"
    property color statusColor: accentColor
    property bool actionEnabled: true

    signal runRequested()

    height: 39
    radius: root.theme.radiusSm
    color: rowHover.hovered ? root.theme.glassHoverSurface : "transparent"

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.theme.spacingTokens.xsPlus
        anchors.rightMargin: root.theme.spacingTokens.xsPlus
        spacing: root.theme.spacingTokens.smPlus

        Text {
            visible: root.tablerIcon.length === 0
            width: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.accentColor
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.theme.iconTokens.mdPlus
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            visible: root.tablerIcon.length > 0
            width: 20
            height: root.theme.iconTokens.lgPlus
            anchors.verticalCenter: parent.verticalCenter

            TablerIcon {
                anchors.centerIn: parent
                width: root.theme.iconTokens.lgPlus
                height: root.theme.iconTokens.lgPlus
                iconName: root.tablerIcon
                iconColor: root.accentColor
            }
        }

        Column {
            width: parent.width - 20 - statusBlock.width - runButton.width - 21
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.title
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.subtitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.subtitle
                color: root.theme.surfaceVariantForeground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                elide: Text.ElideRight
            }
        }

        Text {
            id: statusBlock
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusText
            color: root.statusColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.typeTokens.body
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
        }

        Rectangle {
            id: runButton
            width: 25
            height: 25
            radius: root.theme.radiusButton
            anchors.verticalCenter: parent.verticalCenter
            color: runHover.hovered
                   ? root.theme.glassHoverSurface
                   : root.theme.glassCardSurface
            opacity: root.actionEnabled ? 1 : 0.45

            TablerIcon {
                anchors.centerIn: parent
                width: root.theme.iconTokens.smPlus
                height: root.theme.iconTokens.smPlus
                iconName: "bar-play"
                iconColor: root.accentColor
            }

            HoverHandler { id: runHover }
            TapHandler {
                enabled: root.actionEnabled
                onTapped: root.runRequested()
            }
        }
    }

    HoverHandler { id: rowHover }
}
