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
            readonly property color selectedColor: itemId === "extra-low-power" || itemId === "80"
                ? root.theme.green
                : (itemId === "performance" || itemId === "100" ? root.theme.yellow : root.theme.accent)

            width: (root.width - (root.spacing * (root.effectiveProfiles.length - 1))) / Math.max(1, root.effectiveProfiles.length)
            height: 32
            radius: root.theme.radiusSm

            color: selected
                   ? root.theme.withAlpha(btn.selectedColor, 0.16)
                   : (profileHover.hovered
                      ? root.theme.glassHoverSurface
                      : root.theme.glassCardSurface)

            border.width: 1
            border.color: selected
                          ? btn.selectedColor
                          : (profileHover.hovered ? root.theme.pillBorderHover : root.theme.borderRegular)

            opacity: root.available ? 1.0 : 0.48

            Behavior on color {
                enabled: root.theme.qmlAnimationsEnabled
                ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
            }
            Behavior on border.color {
                enabled: root.theme.qmlAnimationsEnabled
                ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
            }

            // Do not bind Row.width to Text.width (causes circular layout collapse);
            // size Text against btn.width so icon and label always sit side-by-side.
            Row {
                anchors.centerIn: parent
                spacing: root.theme.spacingTokens.xs

                TablerIcon {
                    visible: btn.itemIcon.length > 0
                    width: root.theme.iconTokens.md
                    height: root.theme.iconTokens.md
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: btn.itemIcon
                    iconColor: btn.selected ? btn.selectedColor : root.theme.surfaceVariantForeground
                }

                Text {
                    readonly property real maxLabelWidth: Math.max(
                        12,
                        btn.width - 10 - (btn.itemIcon.length > 0 ? root.theme.iconTokens.md + root.theme.spacingTokens.xs : 0)
                    )
                    width: Math.min(implicitWidth, maxLabelWidth)
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
