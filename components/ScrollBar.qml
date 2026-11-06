import QtQuick

// Shared vertical scrollbar for Flickable based surfaces.
Item {
    id: root

    required property Flickable target
    required property var theme
    required property var wheelController
    property color thumbColor: theme.accent
    property real idleOpacity: 0.4
    property real hoverOpacity: 0.9
    property real rightInset: 1

    width: 10
    visible: enabled && target && target.visible && maxScroll > 0

    readonly property real maxScroll: target
        ? Math.max(0, target.contentHeight - target.height) : 0
    readonly property real thumbHeight: target
        ? Math.max(24, Math.min(height, height * target.height / Math.max(1, target.contentHeight)))
        : height
    readonly property real maxThumbY: Math.max(1, height - thumbHeight)
    readonly property bool hovered: mouseArea.containsMouse || mouseArea.pressed

    Rectangle {
        id: thumb
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        width: root.hovered ? 5 : 3
        height: root.thumbHeight
        y: root.target && root.maxScroll > 0
           ? Math.max(0, Math.min(root.maxThumbY,
                root.target.contentY / root.maxScroll * root.maxThumbY))
           : 0
        radius: width / 2
        color: root.thumbColor
        opacity: root.hovered ? root.hoverOpacity : root.idleOpacity

        Behavior on width {
            enabled: root.theme.qmlAnimationsEnabled
            NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
        }
        Behavior on color {
            enabled: root.theme.qmlAnimationsEnabled
            ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
        }
        Behavior on opacity {
            enabled: root.theme.qmlAnimationsEnabled
            NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real grabOffsetY: 0

        function moveThumb(mouseY) {
            const y = Math.max(0, Math.min(root.maxThumbY, mouseY - grabOffsetY))
            if (root.target && root.maxThumbY > 0)
                root.target.contentY = y / root.maxThumbY * root.maxScroll
        }

        onPressed: function(mouse) {
            if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                grabOffsetY = mouse.y - thumb.y
            } else {
                grabOffsetY = root.thumbHeight / 2
                moveThumb(mouse.y)
            }
        }

        onPositionChanged: function(mouse) {
            if (pressed)
                moveThumb(mouse.y)
        }

        onWheel: function(event) {
            root.wheelController.handle(event)
        }
    }
}
