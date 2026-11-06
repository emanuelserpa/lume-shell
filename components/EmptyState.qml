import QtQuick

Item {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property string title: ""
    property string subtitle: ""
    property bool horizontal: false
    property int iconSize: theme.iconTokens.hero
    property int titleSize: theme.typeTokens.body
    property int subtitleSize: theme.typeTokens.caption
    property int itemSpacing: theme.spacingTokens.sm
    property color iconColor: theme.surfaceVariantForeground
    property color titleColor: theme.surfaceForeground
    property color subtitleColor: theme.surfaceVariantForeground

    implicitWidth: Math.max(verticalContent.implicitWidth, horizontalContent.implicitWidth)
    implicitHeight: horizontal ? horizontalContent.implicitHeight : verticalContent.implicitHeight

    Column {
        id: verticalContent
        anchors.centerIn: parent
        spacing: root.itemSpacing
        visible: !root.horizontal

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.icon.length > 0 && root.tablerIcon.length === 0
            text: root.icon
            color: root.iconColor
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.iconSize
        }

        TablerIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.tablerIcon.length > 0
            width: root.iconSize
            height: root.iconSize
            iconName: root.tablerIcon
            iconColor: root.iconColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.title.length > 0
            text: root.title
            color: root.titleColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.titleSize
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: root.subtitleColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.subtitleSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    Row {
        id: horizontalContent
        anchors.centerIn: parent
        spacing: root.itemSpacing
        visible: root.horizontal

        Text {
            visible: root.icon.length > 0 && root.tablerIcon.length === 0
            text: root.icon
            color: root.iconColor
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
        }

        TablerIcon {
            visible: root.tablerIcon.length > 0
            width: root.iconSize
            height: root.iconSize
            iconName: root.tablerIcon
            iconColor: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.title.length > 0
            text: root.title
            color: root.titleColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.titleSize
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
