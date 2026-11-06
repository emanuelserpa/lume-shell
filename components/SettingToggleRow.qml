import QtQuick
import qs.components

Item {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property string title: ""
    property string description: ""
    property bool checked: false
    property bool showSurface: true
    property int rowHeight: 44
    property color iconColor: theme.primary
    property color titleColor: theme.foreground
    property color descriptionColor: theme.surfaceVariantForeground
    property string accessibleLabel: title
    property int titleWeight: Font.DemiBold
    property int descriptionPixelSize: theme.typeTokens.meta

    signal toggleRequested(bool checked)

    readonly property bool hovered: hoverHandler.hovered

    width: parent ? parent.width : 0
    height: rowHeight

    Rectangle {
        anchors.fill: parent
        visible: root.showSurface
        radius: root.theme.radiusLg
        color: root.hovered ? root.theme.adaptiveCardHoverSurface : root.theme.adaptiveCardSurface
        border.width: 1
        border.color: root.theme.adaptiveCardBorder
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.theme.popupInsets.standard
        anchors.rightMargin: root.theme.popupInsets.standard
        spacing: root.theme.spacingTokens.md

        Text {
            visible: root.icon.length > 0 && root.tablerIcon.length === 0
            width: visible ? root.theme.iconTokens.lgPlus : 0
            text: root.icon
            color: root.iconColor
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.theme.iconTokens.lgPlus
            anchors.verticalCenter: parent.verticalCenter
        }

        TablerIcon {
            visible: root.tablerIcon.length > 0
            width: visible ? root.theme.iconTokens.lgPlus : 0
            height: root.theme.iconTokens.lgPlus
            iconName: root.tablerIcon
            iconColor: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: Math.max(0, parent.width - (toggleControl.width + parent.spacing
                   + ((root.icon.length > 0 || root.tablerIcon.length > 0)
                      ? root.theme.iconTokens.lgPlus + parent.spacing : 0)))
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacingTokens.micro

            Text {
                width: parent.width
                text: root.title
                color: root.titleColor
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.body
                font.weight: root.titleWeight
                elide: Text.ElideRight
            }

            Text {
                visible: root.description.length > 0
                width: parent.width
                text: root.description
                color: root.descriptionColor
                font.family: root.theme.fontFamily
                font.pixelSize: root.descriptionPixelSize
                elide: Text.ElideRight
            }
        }

        MaterialSwitch {
            id: toggleControl
            theme: root.theme
            checked: root.checked
            enabled: root.enabled
            accessibleLabel: root.accessibleLabel
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.toggleRequested(checked)
        }
    }

    HoverHandler { id: hoverHandler }

    TapHandler {
        enabled: root.enabled
        onTapped: function(point) {
            const controlLeft = toggleControl.mapToItem(root, 0, 0).x
            if (point.position.x < controlLeft)
                root.toggleRequested(!root.checked)
        }
    }
}
