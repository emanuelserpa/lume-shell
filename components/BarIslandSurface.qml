import QtQuick

Item {
    id: root

    required property var theme
    required property Item target

    anchors.horizontalCenter: root.target.horizontalCenter
    anchors.verticalCenter: root.target.verticalCenter
    width: root.target.implicitWidth + root.theme.barIslandPadding * 2
    height: root.theme.barIslandHeight

    Rectangle {
        x: 0
        y: root.theme.barIslandShadowOffset
        width: parent.width
        height: parent.height
        radius: root.theme.barIslandRadius
        color: root.theme.barIslandShadow
    }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.barIslandRadius
        color: root.theme.barIslandSurface
        border.width: 1
        border.color: root.theme.barIslandBorder
    }
}
