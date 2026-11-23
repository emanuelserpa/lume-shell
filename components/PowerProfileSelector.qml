pragma ComponentBehavior: Bound

import QtQuick

Row {
    id: root

    required property var theme
    property var profiles: []
    property string activeProfile: ""
    property bool available: true
    property bool busy: false

    signal profileRequested(string profileId)

    width: parent ? parent.width : 0
    spacing: root.theme.spacingTokens.sm

    readonly property var fallbackProfiles: [
        { id: "extra-low-power", label: "Ultra Eco", icon: "leaf" },
        { id: "power-saver", label: "Economia" },
        { id: "balanced", label: "Equilibrado" },
        { id: "performance", label: "Desempenho" }
    ]

    readonly property var effectiveProfiles:
        (profiles && profiles.length > 0) ? profiles : fallbackProfiles

    Repeater {
        model: root.effectiveProfiles

        delegate: Rectangle {
            id: btn
            required property var modelData

            readonly property string itemId: String(modelData.id ?? "")
            readonly property string itemIcon: String(modelData.icon ?? "")
            readonly property bool selected: root.activeProfile === itemId
            readonly property color selectedColor: itemId === "extra-low-power"
                ? root.theme.green : root.theme.accent

            width: (root.width - (root.spacing * (root.effectiveProfiles.length - 1))) / Math.max(1, root.effectiveProfiles.length)
            height: 28
            radius: root.theme.radiusSm

            color: selected
                   ? root.theme.glassActiveSurface
                   : (profileHover.hovered
                      ? root.theme.glassHoverSurface
                      : root.theme.glassCardSurface)

            border.width: 1
            border.color: selected
                          ? btn.selectedColor
                          : root.theme.borderRegular

            opacity: root.available ? 1.0 : 0.48

            Row {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                spacing: 3

                TablerIcon {
                    visible: btn.itemIcon.length > 0
                    width: visible ? root.theme.iconTokens.sm : 0
                    height: root.theme.iconTokens.sm
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: btn.itemIcon
                    iconColor: btn.selected ? btn.selectedColor : root.theme.green
                }

                Text {
                    width: Math.min(implicitWidth, parent.width - (btn.itemIcon.length > 0 ? root.theme.iconTokens.sm + 3 : 0))
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(btn.modelData.label ?? "")
                    color: btn.selected ? btn.selectedColor : root.theme.offWhite
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    font.weight: btn.selected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            HoverHandler {
                id: profileHover
                cursorShape: root.available && !root.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: root.available && !root.busy
                onTapped: root.profileRequested(btn.itemId)
            }
        }
    }
}
