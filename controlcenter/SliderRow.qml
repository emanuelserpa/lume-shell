import QtQuick
import qs.components

Item {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property real value: 0
    property real maximum: 1
    property real minimum: 0
    property string valueText: ""
    property color accent: theme.accent
    property bool available: true
    property bool wheelEnabled: true
    property bool iconClickable: false
    property bool showIcon: true
    property bool showValue: true
    property bool thumbAlwaysVisible: false
    property int iconWidth: 30
    property int valueWidth: 46
    property int trackRightInset: 0
    property int trackHeight: root.theme.sliderTokens.trackHeight
    property int trackRadius: trackHeight / 2
    property int thumbSize: root.theme.sliderTokens.thumbSize

    signal valueRequested(real value)
    signal iconActivated()

    implicitHeight: root.theme.softControlHeight

    readonly property real step: root.maximum > 10 ? 5 : 0.05

    function stepDelta(up) {
        if (!root.available || !root.wheelEnabled) return
        var next = up ? (root.value + root.step) : (root.value - root.step)
        if (root.maximum <= 10) {
            next = Math.round(next * 100) / 100
        }
        next = Math.max(root.minimum, Math.min(root.maximum, next))
        root.valueRequested(next)
    }

    WheelHandler {
        enabled: root.available && root.wheelEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (event.angleDelta.y !== 0)
                root.stepDelta(event.angleDelta.y > 0)
        }
    }

    Item {
        id: iconLabel
        visible: root.showIcon
        width: root.showIcon ? root.iconWidth : 0
        height: parent.height
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Text {
            visible: root.tablerIcon.length === 0
            anchors.centerIn: parent
            text: root.icon
            color: root.available ? root.accent : root.theme.grey
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.theme.iconTokens.xl
            horizontalAlignment: Text.AlignHCenter
        }

        TablerIcon {
            visible: root.tablerIcon.length > 0
            anchors.centerIn: parent
            width: root.theme.iconTokens.lgPlus
            height: root.theme.iconTokens.lgPlus
            iconName: root.tablerIcon
            iconColor: root.available ? root.accent : root.theme.grey
        }

        HoverHandler {
            enabled: root.iconClickable && root.available
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: root.iconClickable && root.available
            acceptedButtons: Qt.LeftButton
            onTapped: root.iconActivated()
        }
    }

    Item {
        id: trackArea
        anchors.left: iconLabel.right
        anchors.leftMargin: root.showIcon ? 8 : 0
        anchors.right: valueLabel.left
        anchors.rightMargin: root.showValue ? 10 : root.trackRightInset
        anchors.verticalCenter: parent.verticalCenter
        height: 24

        Rectangle {
            id: track
            width: parent.width
            height: root.trackHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: root.trackRadius
            color: root.theme.sliderTrack
            clip: true

            Rectangle {
                id: fill
                width: parent.width * Math.max(0, Math.min(1, (root.value - root.minimum) / Math.max(0.0001, root.maximum - root.minimum)))
                height: parent.height
                radius: parent.radius
                color: root.available ? root.accent : root.theme.grey
            }
        }

        Rectangle {
            width: root.thumbSize
            height: root.thumbSize
            radius: root.thumbSize / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, fill.width - width / 2))
            color: root.theme.surfaceContainerHighest
            border.width: 2
            border.color: root.accent
            visible: root.available && (root.thumbAlwaysVisible || trackMouse.containsMouse || trackMouse.pressed)
            scale: trackMouse.pressed ? 1.08 : 1

            Behavior on scale {
                enabled: root.theme.qmlAnimationsEnabled
                NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
            }
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            enabled: root.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function apply(mouseX) {
                const ratio = Math.max(0, Math.min(1, mouseX / width))
                root.valueRequested(root.minimum + ratio * (root.maximum - root.minimum))
            }

            onPressed: function(mouse) { apply(mouse.x) }
            onPositionChanged: function(mouse) {
                if (pressed)
                    apply(mouse.x)
            }
        }
    }

    Text {
        id: valueLabel
        visible: root.showValue
        width: root.showValue ? root.valueWidth : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.valueText
        color: root.available ? root.theme.offWhite : root.theme.grey
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.dashboardLabelFontSize
        horizontalAlignment: Text.AlignRight
    }
}
