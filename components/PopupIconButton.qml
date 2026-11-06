import QtQuick

Rectangle {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property color normalBackground: theme.glassCardSurface
    property color hoverBackground: theme.glassHoverSurface
    property color normalForeground: theme.offWhite
    property color hoverForeground: theme.primary
    property int iconPixelSize: theme.iconTokens.mdPlus

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: theme.radiusButton
    color: iconHover.hovered ? root.hoverBackground : root.normalBackground
    scale: iconPress.pressed && root.theme.qmlAnimationsEnabled ? root.theme.motionPressScale : 1

    Behavior on scale {
        enabled: root.theme.qmlAnimationsEnabled
        NumberAnimation { duration: root.theme.motionPress; easing.type: root.theme.motionEasing }
    }

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    Text {
        anchors.centerIn: parent
        visible: root.tablerIcon.length === 0
        text: root.icon
        color: iconHover.hovered ? root.hoverForeground : root.normalForeground
        font.family: root.theme.nerdFontFamily
        font.pixelSize: root.iconPixelSize
    }

    TablerIcon {
        anchors.centerIn: parent
        visible: root.tablerIcon.length > 0
        width: root.iconPixelSize
        height: root.iconPixelSize
        iconName: root.tablerIcon
        iconColor: iconHover.hovered ? root.hoverForeground : root.normalForeground
    }

    HoverHandler {
        id: iconHover
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: iconPress
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
