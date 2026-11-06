import QtQuick

Rectangle {
    id: root

    required property var theme
    property bool active: false
    property bool hoverEnabled: true
    property int rowHeight: 44
    property int cornerRadius: theme.radiusMd
    property color idleColor: theme.glassCardSurface
    property color hoverColor: theme.glassHoverSurface
    property color activeColor: theme.glassActiveSurface
    property int idleBorderWidth: 1
    property int activeBorderWidth: 1
    property color idleBorderColor: theme.borderSubtle
    property color hoverBorderColor: idleBorderColor
    property color activeBorderColor: theme.withAlpha(theme.primary, 0.35)
    property int cursorShape: Qt.ArrowCursor
    default property alias content: contentLayer.data

    // Standard content slots. When title, leadingIcon or subtitle is set,
    // the row renders the standard layout below and ignores default content.
    // Otherwise it keeps the legacy behavior (default content only).
    // Tap handling stays with the caller (no TapHandler here).
    property string leadingIcon: ""
    property string leadingTablerIcon: ""
    property color leadingIconColor: theme.primary
    property int leadingIconPixelSize: theme.iconTokens.lg
    property int leadingSlotWidth: leadingIconPixelSize
    // Image icon alternative (e.g. tray/app icons). Takes precedence over
    // the glyph when set; checkmarks etc. keep using leadingIcon.
    property url leadingImage: ""
    readonly property bool hasLeadingImage: leadingImage.toString().length > 0
    readonly property bool hasLeading: hasLeadingImage || leadingIcon.length > 0 || leadingTablerIcon.length > 0
    property string title: ""
    property color titleColor: theme.foreground
    property int titlePixelSize: theme.typeTokens.body
    property int titleWeight: Font.DemiBold
    property string subtitle: ""
    property color subtitleColor: theme.surfaceVariantForeground
    property int subtitlePixelSize: theme.typeTokens.meta
    property Component trailing: null
    readonly property bool useStandardLayout: title.length > 0 || leadingIcon.length > 0 || leadingTablerIcon.length > 0 || subtitle.length > 0

    // Optional 1px divider above the row (e.g. grouping session actions).
    property bool topDivider: false
    property color dividerColor: theme.glassBorderSubtle
    // Pointer handlers are kept outside the default content slot, which is
    // hidden when the row uses its built-in title/icon layout.
    property alias interactionHandlers: interactionHandlerHost.data

    readonly property bool hovered: hoverHandler.hovered

    width: parent ? parent.width : 0
    height: root.rowHeight
    radius: root.cornerRadius
    color: root.active
        ? root.activeColor
        : (root.hovered ? root.hoverColor : root.idleColor)
    border.width: root.active ? root.activeBorderWidth : root.idleBorderWidth
    border.color: root.active
        ? root.activeBorderColor
        : (root.hovered ? root.hoverBorderColor : root.idleBorderColor)
    clip: true

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }
    Behavior on border.color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    Rectangle {
        visible: root.topDivider
        x: 4
        y: -2
        width: parent.width - 8
        height: 1
        color: root.dividerColor
    }

    Row {
        id: standardLayout
        visible: root.useStandardLayout
        anchors.fill: parent
        anchors.leftMargin: root.theme.popupInsets.compact
        anchors.rightMargin: root.theme.popupInsets.compact
        spacing: root.theme.spacingTokens.md

        Item {
            id: leadingSlot
            visible: root.hasLeading
            width: visible ? root.leadingSlotWidth : 0
            height: root.leadingIconPixelSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                visible: root.hasLeadingImage
                anchors.centerIn: parent
                width: root.leadingIconPixelSize
                height: root.leadingIconPixelSize
                sourceSize.width: root.leadingIconPixelSize
                sourceSize.height: root.leadingIconPixelSize
                source: root.leadingImage
            }

            TablerIcon {
                visible: root.leadingTablerIcon.length > 0
                anchors.centerIn: parent
                width: root.leadingIconPixelSize
                height: root.leadingIconPixelSize
                iconName: root.leadingTablerIcon
                iconColor: root.leadingIconColor
            }

            Text {
                visible: !root.hasLeadingImage && root.leadingTablerIcon.length === 0 && root.leadingIcon.length > 0
                anchors.centerIn: parent
                text: root.leadingIcon
                color: root.leadingIconColor
                font.family: root.theme.nerdFontFamily
                font.pixelSize: root.leadingIconPixelSize
                elide: Text.ElideRight
            }
        }

        Column {
            width: Math.max(0, parent.width - leadingSlot.width
                - (leadingSlot.width > 0 ? parent.spacing : 0)
                - (trailingLoader.item ? trailingLoader.width + parent.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacingTokens.micro

            Text {
                visible: root.title.length > 0
                width: parent.width
                text: root.title
                color: root.titleColor
                font.family: root.theme.fontFamily
                font.pixelSize: root.titlePixelSize
                font.weight: root.titleWeight
                elide: Text.ElideRight
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

        Loader {
            id: trailingLoader
            anchors.verticalCenter: parent.verticalCenter
            active: root.trailing !== null
            sourceComponent: root.trailing
        }
    }

    Item {
        id: contentLayer
        visible: !root.useStandardLayout
        anchors.fill: parent
    }

    Item {
        id: interactionHandlerHost
        anchors.fill: parent
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.hoverEnabled
        cursorShape: root.cursorShape
    }
}
