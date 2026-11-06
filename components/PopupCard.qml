import QtQuick

// Single source of truth for popup surfaces: shared visuals (radius,
// background, border, focus) plus a subtle scale, lift and fade transition.
// pass cardColor/frameColor/cardClip only where a popup differs.
Rectangle {
    id: root

    required property var theme
    property bool opened: false
    property color cardColor: theme.popupBackground
    property color frameColor: theme.borderPopup
    property bool cardClip: false
    property int cornerRadius: theme.radiusPopup
    property real popupOffset: opened ? 0 : theme.motionPopupOffset

    clip: cardClip
    radius: cornerRadius
    color: cardColor
    border.width: 1
    border.color: frameColor
    focus: true

    // Deliver Escape to the focused popup's Keys handler instead of allowing
    // another window's Shortcut to consume it (including hidden popups).
    Keys.onShortcutOverride: function(event) {
        if (event.key === Qt.Key_Escape)
            event.accepted = true
    }

    opacity: opened ? 1 : 0
    scale: opened ? 1 : theme.motionPopupScale

    transformOrigin: Item.Center
    transform: Translate { y: root.popupOffset }
    Behavior on opacity { enabled: root.theme.qmlAnimationsEnabled; NumberAnimation { duration: root.opened ? root.theme.motionPopup : root.theme.motionPopupExit; easing.type: root.theme.motionTransientFadeEasing } }
    Behavior on scale { enabled: root.theme.qmlAnimationsEnabled; NumberAnimation { duration: root.opened ? root.theme.motionPopup : root.theme.motionPopupExit; easing.type: root.theme.motionEasing } }
    Behavior on popupOffset { enabled: root.theme.qmlAnimationsEnabled; NumberAnimation { duration: root.opened ? root.theme.motionPopup : root.theme.motionPopupExit; easing.type: root.theme.motionEasing } }
}
