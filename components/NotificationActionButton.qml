import QtQuick

Rectangle {
    id: root

    required property var action
    required property var theme
    property int buttonHeight: 40
    property int horizontalPadding: theme.spacingTokens.xxl
    property int labelPixelSize: theme.typeTokens.bodyEmphasis

    signal activated()

    implicitWidth: label.implicitWidth + root.horizontalPadding
    implicitHeight: root.buttonHeight
    width: implicitWidth
    height: implicitHeight
    radius: root.theme.radiusButton
    color: activationTap.pressed
          ? root.theme.glassActiveSurface
          : buttonHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
    border.width: 1
    border.color: buttonHover.hovered || activationTap.pressed
                  ? root.theme.pillBorderHover
                  : root.theme.pillBorder

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }
    Behavior on border.color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    function labelForAction(action) {
        const text = String(action?.text ?? "Ação").trim()
        const normalized = text.toLowerCase().replace(/[_-]+/g, " ").replace(/\s+/g, " ")
        const identifier = String(action?.identifier ?? "").toLowerCase().replace(/[_-]+/g, " ").trim()

        if (normalized === "open" || normalized === "abrir"
                || identifier === "open" || identifier === "default") return "Abrir"
        if (["mark as read", "mark read", "marcar como lida", "marcar como lido"].includes(normalized)
                || ["mark as read", "mark read"].includes(identifier)) return "Marcar como lida"

        return text
    }

    Text {
        id: label
        z: 1
        anchors.centerIn: parent
        text: root.labelForAction(root.action)
        color: buttonHover.hovered || activationTap.pressed
               ? root.theme.primary
               : root.theme.surfaceVariantForeground
        font.family: root.theme.fontFamily
        font.pixelSize: root.labelPixelSize
        font.weight: Font.Medium
    }

    HoverHandler {
        id: buttonHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: activationTap
        onTapped: {
            if (root.action && typeof root.action.invoke === "function")
                root.action.invoke()
            root.activated()
        }
    }
}
