import QtQuick
import qs.components

Rectangle {
    id: root

    required property var theme
    property color textColor: theme.isLight ? theme.foreground : theme.offWhite
    property alias text: label.text
    property alias fontPixelSize: label.font.pixelSize
    property alias fontFamily: label.font.family
    property real iconSize: fontPixelSize
    property alias mouseArea: mouse
    property bool highlighted: false
    property bool plain: false
    property bool spinning: false
    property string tooltipText: ""
    property bool tooltipOpenLeft: false
    property string tablerIcon: ""
    property color iconColor: textColor

    implicitHeight: root.theme.pillHeight
    implicitWidth: contentRow.implicitWidth + 10
    radius: root.theme.pillRadius
    clip: true
    scale: mouse.pressed && root.theme.qmlAnimationsEnabled ? root.theme.motionPressScale : 1

    Behavior on scale {
        enabled: root.theme.qmlAnimationsEnabled
        NumberAnimation { duration: root.theme.motionPress; easing.type: root.theme.motionEasing }
    }

    color: plain
           ? (highlighted ? root.theme.glassActiveSurface : "transparent")
           : root.theme.pillBackground

    border.width: plain ? 0 : 1
    border.color: (highlighted || mouse.containsMouse || root.activeFocus)
           ? root.theme.pillBorderHover
           : root.theme.pillBorder

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.theme.stateLayer(
            root.theme.surfaceForeground,
            mouse.pressed ? "pressed" : (mouse.containsMouse || root.activeFocus) ? "hover" : "none"
        )

        Behavior on color {
            enabled: root.theme.qmlAnimationsEnabled
            ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
        }
    }

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }
    Behavior on border.color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }

    Row {
        id: contentRow
        z: 1
        anchors.centerIn: parent
        spacing: root.tablerIcon.length > 0 ? root.theme.spacingTokens.xs : 0

        RotationAnimation on rotation {
            running: root.spinning
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            alwaysRunToEnd: true
        }

        TablerIcon {
            width: root.tablerIcon.length > 0 ? root.iconSize : 0
            height: root.iconSize
            visible: root.tablerIcon.length > 0
            iconName: root.tablerIcon
            iconColor: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: label
            visible: text.length > 0
            color: root.textColor
            textFormat: Text.PlainText
            font.family: root.theme.nerdFontFamily
            font.pixelSize: root.theme.fontSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons

    }

    ToolTipBubble {
        theme: root.theme
        target: root
        text: root.tooltipText
        openLeft: root.tooltipOpenLeft
        requestedVisible: (mouse.containsMouse || root.activeFocus) && !mouse.pressed
    }
}
