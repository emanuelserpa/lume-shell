import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string iconName: ""
    property color iconColor: "white"

    Image {
        id: sourceImage
        anchors.fill: parent
        source: root.iconName.length > 0
                ? Qt.resolvedUrl("../assets/tabler/" + root.iconName + ".svg")
                : ""
        sourceSize.width: Math.max(24, Math.round(root.width * 2))
        sourceSize.height: Math.max(24, Math.round(root.height * 2))
        fillMode: Image.PreserveAspectFit
        visible: false
        asynchronous: true
        smooth: true
        mipmap: true
    }

    MultiEffect {
        anchors.fill: parent
        source: sourceImage
        visible: root.iconName.length > 0
        colorization: 1.0
        colorizationColor: root.iconColor
    }
}
