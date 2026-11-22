import QtQuick
import qs.components
import "../services/SliderLogic.js" as SliderLogic

Item {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property real value: 0
    property real maximum: 1
    property real minimum: 0
    // Optional drag/click ceiling inside [minimum, maximum]. Values may still
    // exceed it via the wheel up to `maximum` (e.g. 100% drag cap, 150% boost).
    property real dragMaximum: maximum
    property real referenceValue: -1
    property string valueText: ""
    property color accent: theme.accent
    property color boostAccent: theme.yellow
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

    property real _wheelAngleAccum: 0
    property real _wheelPixelAccum: 0

    signal valueRequested(real value)
    signal iconActivated()

    implicitHeight: root.theme.softControlHeight

    readonly property real step: root.maximum > 10 ? 5 : 0.05
    readonly property bool hasReference: root.referenceValue >= root.minimum && root.referenceValue <= root.maximum
    readonly property bool hasBoostZone: SliderLogic.hasBoostZone(root.minimum, root.maximum, root.referenceValue)
    readonly property real valueRatio: SliderLogic.normalizedRatio(root.value, root.minimum, root.maximum)
    readonly property real referenceRatio: SliderLogic.normalizedRatio(root.referenceValue, root.minimum, root.maximum)
    readonly property bool isBoosted: SliderLogic.isBoosted(root.value, root.minimum, root.maximum, root.referenceValue)

    function stepDelta(up) {
        if (!root.available || !root.wheelEnabled) return
        root.valueRequested(SliderLogic.stepValue(
            root.value, up, root.step, root.minimum, root.maximum, root.referenceValue))
    }

    WheelHandler {
        enabled: root.available && root.wheelEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            event.accepted = true
            if (event.pixelDelta.y !== 0) {
                root._wheelPixelAccum += event.pixelDelta.y
                const threshold = 24
                while (Math.abs(root._wheelPixelAccum) >= threshold) {
                    const up = root._wheelPixelAccum > 0
                    root._wheelPixelAccum -= up ? threshold : -threshold
                    root.stepDelta(up)
                }
            } else if (event.angleDelta.y !== 0) {
                root._wheelAngleAccum += event.angleDelta.y
                const threshold = 120
                while (Math.abs(root._wheelAngleAccum) >= threshold) {
                    const up = root._wheelAngleAccum > 0
                    root._wheelAngleAccum -= up ? threshold : -threshold
                    root.stepDelta(up)
                }
            }
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

            // Distinct subtle backdrop for the scroll-only boost region (> referenceValue).
            Rectangle {
                visible: root.hasBoostZone
                x: track.width * root.referenceRatio
                width: Math.max(0, track.width - x)
                height: parent.height
                color: root.theme.withAlpha(root.boostAccent, root.available ? 0.14 : 0.06)
            }

            Rectangle {
                id: fill
                width: parent.width * root.valueRatio
                height: parent.height
                radius: parent.radius
                color: root.available ? root.accent : root.theme.grey
            }

            // Highlight the portion of fill extending past referenceValue.
            Rectangle {
                visible: root.isBoosted
                x: track.width * root.referenceRatio
                width: Math.max(0, fill.width - x)
                height: parent.height
                color: root.available ? root.boostAccent : root.theme.grey
            }
        }

        // Reference notch (e.g. 100% unity mark) layered cleanly behind the thumb.
        Rectangle {
            visible: root.hasReference
            x: Math.max(0, Math.min(track.width - width, track.width * root.referenceRatio - width / 2))
            y: track.y - 2
            width: 2
            height: track.height + 4
            radius: 1
            color: root.theme.surfaceForeground
            opacity: root.available ? 0.80 : 0.35
            z: 1
        }

        Rectangle {
            id: thumb
            width: root.thumbSize
            height: root.thumbSize
            radius: root.thumbSize / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, fill.width - width / 2))
            color: root.theme.surfaceContainerHighest
            border.width: 2
            border.color: root.isBoosted && root.available ? root.boostAccent : root.accent
            visible: root.available && (root.thumbAlwaysVisible || trackMouse.containsMouse || trackMouse.pressed)
            scale: trackMouse.pressed ? 1.08 : 1
            z: 3

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
                root.valueRequested(SliderLogic.valueFromPointer(
                    mouseX, width, root.minimum, root.maximum, root.dragMaximum))
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
        color: !root.available
               ? root.theme.grey
               : (root.isBoosted ? root.boostAccent : root.theme.offWhite)
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.dashboardLabelFontSize
        font.weight: root.isBoosted ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignRight
    }
}
