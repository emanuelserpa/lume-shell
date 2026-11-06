import QtQuick
import qs.components

Item {
    id: root

    required property var theme
    property var launcherController: null
    property bool plain: false

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    implicitWidth: pill.implicitWidth
    implicitHeight: root.theme ? root.theme.pillHeight : 25

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        tablerIcon: "bar-search"
        iconSize: root.theme.barIconSize
        text: ""
        fontPixelSize: root.theme.iconTokens.lg
        textColor: root.theme.surfaceForeground
        tooltipText: "Busca e aplicativos"

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton && root.launcherController)
                root.launcherController.toggleLauncher()
        }
    }
}
