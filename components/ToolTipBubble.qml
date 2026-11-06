import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property string text: ""
    property bool openLeft: false
    property bool requestedVisible: false
    property int showDelay: 500
    property int maximumTextWidth: 244
    property bool tooltipShown: false

    readonly property bool autoOpenLeft: {
        if (!target) return false
        try {
            let rootItem = target
            while (rootItem.parent) {
                rootItem = rootItem.parent
            }
            const pt = target.mapToItem(rootItem, 0, 0)
            return (pt.x + root.implicitWidth + 12) > rootItem.width
        } catch (e) {
            return false
        }
    }

    readonly property bool effectiveOpenLeft: root.openLeft || autoOpenLeft

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: root.effectiveOpenLeft
                  ? (Edges.Bottom | Edges.Right)
                  : (Edges.Bottom | Edges.Left)
    anchor.gravity: root.effectiveOpenLeft
    // qmllint enable missing-type
                    ? (Edges.Bottom | Edges.Left)
                    : (Edges.Bottom | Edges.Right)
    anchor.margins.top: root.theme.spacingTokens.sm
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: body.width + root.theme.popupInsets.standard * 2
    implicitHeight: body.implicitHeight + root.theme.popupInsets.compact * 2
    color: "transparent"
    surfaceFormat.opaque: false
    visible: root.tooltipShown && root.text.length > 0

    onRequestedVisibleChanged: {
        if (requestedVisible && text.length > 0) {
            showTimer.restart()
        } else {
            showTimer.stop()
            tooltipShown = false
        }
    }

    onTextChanged: {
        if (text.length === 0) {
            showTimer.stop()
            tooltipShown = false
        }
    }

    Timer {
        id: showTimer
        interval: root.showDelay
        repeat: false
        onTriggered: {
            if (root.requestedVisible && root.text.length > 0)
                root.tooltipShown = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.radiusMd

        color: root.theme.surfaceContainerHigh

        border.width: 1
        border.color: root.theme.borderSubtle

        Text {
            id: body

            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.standard
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.maximumTextWidth, implicitWidth)

            text: root.text
            color: root.theme.foreground

            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.typeTokens.subtitle
            font.weight: Font.Normal

            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignLeft
            lineHeight: 1.1
        }
    }
}
