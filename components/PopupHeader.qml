import QtQuick

Item {
    id: root

    required property var theme
    property string leadingIcon: ""
    property string leadingTablerIcon: ""
    property color leadingIconColor: theme.primary
    property string title: ""
    property color titleColor: theme.foreground
    property string subtitle: ""
    property color subtitleColor: theme.surfaceVariantForeground
    property int subtitlePixelSize: theme.typeTokens.meta
    property bool parentAnchored: true
    property int headerHeight: 38
    property int horizontalInset: theme.popupInsets.outer
    property int topInset: theme.popupInsets.outer
    property int iconBoxSize: 36
    property int iconBoxRadius: iconBoxSize >= 30 ? theme.radiusButton : 0
    property color iconBoxColor: theme.glassPanelSurface
    property int iconBoxBorderWidth: 0
    property color iconBoxBorderColor: "transparent"
    property int iconPixelSize: theme.iconTokens.xxl
    property int titlePixelSize: theme.typeTokens.title
    property int titleWeight: Font.Bold
    property real titleLetterSpacing: 0
    property Component titleAccessory: null
    property bool titleInteractive: false
    property int contentGap: theme.popupInsets.standard
    property int contentLeftInset: 0
    property int subtitleSpacing: theme.spacingTokens.micro
    property int actionSpacing: theme.spacingTokens.sm

    signal titleActivated()
    readonly property bool titleHovered: titleHover.hovered

    default property alias actions: actionRow.data

    anchors.top: parentAnchored ? parent.top : undefined
    anchors.topMargin: parentAnchored ? topInset : 0
    anchors.left: parentAnchored ? parent.left : undefined
    anchors.leftMargin: parentAnchored ? horizontalInset : 0
    anchors.right: parentAnchored ? parent.right : undefined
    anchors.rightMargin: parentAnchored ? horizontalInset : 0
    width: parentAnchored ? undefined : (parent ? parent.width : 0)
    height: headerHeight

    Rectangle {
        id: iconBox
        width: root.leadingIcon.length > 0 || root.leadingTablerIcon.length > 0 ? root.iconBoxSize : 0
        height: root.iconBoxSize
        radius: root.iconBoxRadius
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: root.iconBoxColor
        border.width: root.iconBoxBorderWidth
        border.color: root.iconBoxBorderColor

        Text {
            anchors.centerIn: parent
            visible: root.leadingTablerIcon.length === 0
            text: root.leadingIcon
            color: root.leadingIconColor
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.iconPixelSize
        }

        TablerIcon {
            anchors.centerIn: parent
            width: root.iconPixelSize
            height: root.iconPixelSize
            visible: root.leadingTablerIcon.length > 0
            iconName: root.leadingTablerIcon
            iconColor: root.leadingIconColor
        }
    }

    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: (iconBox.width > 0 ? root.contentGap : 0) + root.contentLeftInset
        anchors.right: actionRow.left
        anchors.rightMargin: root.theme.popupInsets.standard
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.subtitleSpacing

        Row {
            id: titleRow
            width: parent.width
            spacing: root.theme.spacingTokens.xs

            Text {
                width: Math.min(implicitWidth,
                    Math.max(0, titleRow.width - (titleAccessoryLoader.item ? titleAccessoryLoader.width + titleRow.spacing : 0)))
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: root.titleColor
                font.family: root.theme.fontFamily
                font.pixelSize: root.titlePixelSize
                font.weight: root.titleWeight
                font.letterSpacing: root.titleLetterSpacing
                elide: Text.ElideRight
            }

            Loader {
                id: titleAccessoryLoader
                active: root.titleAccessory !== null
                sourceComponent: root.titleAccessory
                anchors.verticalCenter: parent.verticalCenter
            }

            TapHandler {
                enabled: root.titleInteractive
                acceptedButtons: Qt.LeftButton
                onTapped: root.titleActivated()
            }

            HoverHandler {
                id: titleHover
                enabled: root.titleInteractive
                cursorShape: root.titleInteractive ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        Text {
            visible: root.subtitle.length > 0
            width: parent.width
            text: root.subtitle
            color: root.subtitleColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.subtitlePixelSize
            elide: Text.ElideRight
        }
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.actionSpacing
    }
}
