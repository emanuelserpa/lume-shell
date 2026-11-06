import QtQuick

Rectangle {
    id: root

    required property var theme
    property int buttonSize: 24
    property string accessibleLabel: "Fechar"

    signal clicked()

    readonly property bool hovered: hover.hovered

    width: buttonSize
    height: buttonSize
    radius: width / 2
    color: hovered ? theme.glassHoverSurface : "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    Text {
        anchors.centerIn: parent
        text: "×"
        color: root.hovered ? root.theme.offWhite : root.theme.surfaceVariantForeground
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.typeTokens.titleMedium
        font.weight: Font.Medium
    }

    HoverHandler {
        id: hover
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
