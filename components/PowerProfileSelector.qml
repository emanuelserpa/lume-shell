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

            readonly property bool selected:
                root.activeProfile === String(modelData.id ?? "")

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
                          ? root.theme.accent
                          : root.theme.borderRegular

            opacity: root.available ? 1.0 : 0.48

            Text {
                anchors.centerIn: parent
                text: String(btn.modelData.label ?? "")
                color: btn.selected
                       ? root.theme.accent
                       : root.theme.offWhite
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                font.weight: btn.selected ? Font.DemiBold : Font.Medium
            }

            HoverHandler {
                id: profileHover
                cursorShape: root.available && !root.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: root.available && !root.busy
                onTapped: root.profileRequested(String(btn.modelData.id ?? ""))
            }
        }
    }
}
