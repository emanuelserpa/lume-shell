import QtQuick
import QtQuick.Controls

Switch {
    id: root

    required property var theme
    property string accessibleLabel: ""

    implicitWidth: 48
    implicitHeight: 32
    padding: 0
    spacing: 0
    focusPolicy: Qt.StrongFocus
    Accessible.name: accessibleLabel

    indicator: Item {
        implicitWidth: 48
        implicitHeight: 32
        x: root.mirrored ? root.width - width : 0
        y: (root.height - height) / 2

        Rectangle {
            id: track
            anchors.centerIn: parent
            width: 46
            height: 28
            radius: height / 2
            color: root.checked ? root.theme.primary : root.theme.surfaceContainerHighest
            border.width: 1
            border.color: root.checked ? root.theme.primary : root.theme.outline

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.theme.stateLayer(
                    root.checked ? root.theme.primaryForeground : root.theme.surfaceForeground,
                    root.down ? "pressed" : root.visualFocus ? "focus" : root.hovered ? "hover" : "none"
                )
            }

            Behavior on color {
                enabled: root.theme.qmlAnimationsEnabled
                ColorAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
            }
        }

        Rectangle {
            id: thumb
            y: (parent.height - height) / 2
            x: root.checked ? parent.width - width - 3 : 4
            width: root.checked ? 24 : 18
            height: width
            radius: width / 2
            color: root.checked ? root.theme.primaryForeground : root.theme.outline

            Behavior on color {
                enabled: root.theme.qmlAnimationsEnabled
                ColorAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
            }

            Behavior on x {
                enabled: root.theme.qmlAnimationsEnabled
                NumberAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
            }

            Behavior on width {
                enabled: root.theme.qmlAnimationsEnabled
                NumberAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
            }

        }
    }
}
