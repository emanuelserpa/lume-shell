import QtQuick

Rectangle {
    id: root

    required property var theme
    required property var holiday
    property bool highlighted: false

    implicitHeight: 42
    radius: root.theme.radiusMd
    color: root.highlighted ? root.theme.glassActiveSurface : root.theme.glassCardSurface
    border.width: 1
    border.color: root.highlighted ? root.theme.glassBorder : root.theme.glassBorderSubtle

    Item {
        anchors.fill: parent

        Text {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: root.theme.spacingTokens.lg
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: root.highlighted ? root.theme.accent : root.theme.offWhite
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.theme.typeTokens.title
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: root.theme.spacingTokens.md
            anchors.right: countdown.left
            anchors.rightMargin: root.theme.spacingTokens.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacingTokens.micro

            Text {
                width: parent.width
                text: String(root.holiday?.name ?? "")
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.dashboardBodyFontSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                text: String(root.holiday?.dateLabel ?? "")
                color: root.theme.grey
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.dashboardMetaFontSize
            }
        }

        Text {
            id: countdown
            anchors.right: parent.right
            anchors.rightMargin: root.theme.spacingTokens.lg
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.holiday?.countdown ?? "")
            color: root.highlighted ? root.theme.accent : root.theme.offWhite
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.dashboardMetaFontSize
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }
    }
}
