// LEGADO: popup não montado no shell atual (pertence ao componente legado bar/Brightness.qml).
import QtQuick
import Quickshell
import qs.components
import qs.controlcenter

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property int brightness: 0
    property bool available: false
    property string deviceName: ""
    property string errorText: ""

    signal brightnessRequested(real value)

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.small
    implicitHeight: 104
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus()
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Keys.onEscapePressed: root.visible = false

        Column {
            anchors.fill: parent
            anchors.margins: 11
            spacing: root.theme.spacingTokens.md

            // Header: Title + Brightness Percentage Badge
            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 20
                horizontalInset: 0
                topInset: 0
                iconBoxSize: 16
                iconBoxColor: "transparent"
                iconPixelSize: root.theme.iconTokens.mdPlus
                contentGap: root.theme.spacingTokens.sm
                leadingTablerIcon: "bar-sun"
                leadingIconColor: root.available ? root.theme.yellow : root.theme.grey
                title: "Brilho"
                titlePixelSize: root.theme.typeTokens.bodyEmphasis
                titleWeight: Font.DemiBold

                Rectangle {
                    height: 18
                    width: Math.max(34, valueText.implicitWidth + 12)
                    radius: height / 2
                    color: root.available ? root.theme.withAlpha(root.theme.yellow, 0.18) : root.theme.glassCardSurface
                    border.width: 1
                    border.color: root.available ? root.theme.withAlpha(root.theme.yellow, 0.35) : root.theme.withAlpha(root.theme.border, 0.30)

                    Text {
                        id: valueText
                        anchors.centerIn: parent
                        text: root.available ? root.brightness + "%" : "--%"
                        color: root.available ? root.theme.yellow : root.theme.grey
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.Bold
                    }
                }
            }

            // Slider Section
            SliderRow {
                id: brightnessSlider
                theme: root.theme
                width: parent.width
                height: 24
                minimum: 1
                maximum: 100
                value: root.brightness
                valueText: ""
                accent: root.theme.yellow
                available: root.available
                showIcon: false
                showValue: false
                thumbAlwaysVisible: true
                wheelEnabled: true
                onValueRequested: function(value) { root.brightnessRequested(value) }
            }

            // Footer Subtitle / Info
            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.right: hintText.left
                    anchors.rightMargin: root.theme.popupInsets.compact
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.errorText.length > 0
                          ? root.errorText
                          : (root.available
                             ? (root.deviceName.length > 0 ? root.deviceName : "Brilho da tela")
                             : "Brilho indisponível")
                    color: root.errorText.length > 0 ? root.theme.red : root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    elide: Text.ElideRight
                }

                Text {
                    id: hintText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Role para ajustar · ±5%"
                    color: root.theme.surfaceVariantForeground
                    opacity: 0.72
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
