pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

PopupWindow {
    id: root

    required property var theme
    required property Item target
    required property bool ownerActive

    property int selectedIndex: 0

    readonly property var modes: DisplayProjectionState.options
    readonly property string activeModeLabel: {
        const selected = root.modes.find(function(option) { return option.selected })
        return String(selected?.title ?? "Layout personalizado")
    }
    readonly property int connectedMonitorCount: DisplayProjectionState.statusData.monitors?.length ?? 0

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.medium
    implicitHeight: 318
    color: "transparent"
    surfaceFormat.opaque: false
    visible: root.ownerActive && DisplayProjectionState.opened
    grabFocus: true

    function activate(index) {
        if (index < 0 || index >= root.modes.length || DisplayProjectionState.busy)
            return
        root.selectedIndex = index
        DisplayProjectionState.applyMode(root.modes[index].id)
    }

    onVisibleChanged: {
        if (!visible)
            return
        const selected = root.modes.findIndex(function(option) { return option.selected })
        root.selectedIndex = selected >= 0 ? selected : 0
        card.forceActiveFocus()
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        cardClip: true
        focus: true

        Keys.onEscapePressed: DisplayProjectionState.close()
        Keys.onUpPressed: {
            if (root.modes.length > 0)
                root.selectedIndex = (root.selectedIndex + root.modes.length - 1) % root.modes.length
        }
        Keys.onDownPressed: {
            if (root.modes.length > 0)
                root.selectedIndex = (root.selectedIndex + 1) % root.modes.length
        }
        Keys.onReturnPressed: root.activate(root.selectedIndex)
        Keys.onEnterPressed: root.activate(root.selectedIndex)

        PopupHeader {
            id: header
            theme: root.theme
            leadingTablerIcon: "device-desktop"
            title: "Projetar"
            subtitle: DisplayProjectionState.loading
                ? "Detectando telas…"
                : root.connectedMonitorCount + (root.connectedMonitorCount === 1
                    ? " tela conectada · " : " telas conectadas · ") + root.activeModeLabel
            subtitleColor: root.theme.surfaceVariantForeground
            horizontalInset: root.theme.popupInsets.large
            topInset: root.theme.popupInsets.large
            headerHeight: 44
            iconBoxSize: 32
            iconBoxRadius: root.theme.radiusSm
            iconBoxColor: root.theme.glassHoverSurface
            iconPixelSize: root.theme.iconTokens.lg
            contentGap: root.theme.spacingTokens.sm
            titlePixelSize: root.theme.typeTokens.subtitle
        }

        Column {
            id: modeList
            anchors.top: header.bottom
            anchors.topMargin: root.theme.spacingTokens.md
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.theme.popupInsets.md
            anchors.rightMargin: root.theme.popupInsets.md
            spacing: root.theme.spacingTokens.xs

            Repeater {
                model: root.modes

                delegate: PopupListRow {
                    id: modeRow
                    required property var modelData
                    required property int index

                    theme: root.theme
                    rowHeight: 48
                    active: root.selectedIndex === modeRow.index || Boolean(modeRow.modelData.selected)
                    activeColor: modeRow.modelData.selected
                        ? root.theme.glassActiveSurface
                        : root.theme.glassHoverSurface
                    activeBorderColor: modeRow.modelData.selected
                        ? root.theme.withAlpha(root.theme.primary, 0.36)
                        : root.theme.borderSubtle
                    leadingTablerIcon: "device-desktop"
                    leadingIconPixelSize: root.theme.iconTokens.lg
                    leadingIconColor: modeRow.modelData.selected ? root.theme.primary : root.theme.offWhite
                    title: String(modeRow.modelData.title ?? "Modo de tela")
                    titlePixelSize: root.theme.typeTokens.body
                    titleColor: root.theme.foreground
                    titleWeight: modeRow.modelData.selected ? Font.DemiBold : Font.Medium
                    subtitle: String(modeRow.modelData.subtitle ?? "")
                    subtitlePixelSize: root.theme.typeTokens.meta
                    subtitleColor: root.theme.surfaceVariantForeground
                    trailing: Component {
                        Row {
                            spacing: root.theme.spacingTokens.sm
                            anchors.verticalCenter: parent.verticalCenter

                            Item {
                                id: displayPreview
                                width: modeRow.modelData.id === "extend" || modeRow.modelData.id === "duplicate" ? 42 : 21
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                readonly property bool twoScreens:
                                    modeRow.modelData.id === "extend" || modeRow.modelData.id === "duplicate"
                                readonly property bool mirrored: modeRow.modelData.id === "duplicate"

                                Repeater {
                                    model: displayPreview.twoScreens ? 2 : 1
                                    delegate: Rectangle {
                                        required property int index
                                        width: 18
                                        height: 13
                                        x: displayPreview.mirrored
                                            ? (index === 0 ? 7 : 16)
                                            : (displayPreview.twoScreens ? index * 22 : 1)
                                        y: 1
                                        radius: 2
                                        color: modeRow.modelData.selected
                                            ? root.theme.primaryContainer
                                            : root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: modeRow.modelData.selected
                                            ? root.theme.primary
                                            : root.theme.borderSubtle

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.bottom
                                            width: 6
                                            height: 2
                                            radius: 1
                                            color: parent.border.color
                                        }
                                    }
                                }
                            }

                            TablerIcon {
                                visible: modeRow.modelData.selected
                                width: root.theme.iconTokens.md
                                height: root.theme.iconTokens.md
                                iconName: "dashboard-check"
                                iconColor: root.theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    interactionHandlers: Item {
                        TapHandler {
                            enabled: !DisplayProjectionState.busy
                            onTapped: root.activate(modeRow.index)
                        }
                    }
                }
            }
        }

        Text {
            visible: DisplayProjectionState.error.length > 0
            anchors.left: modeList.left
            anchors.right: modeList.right
            anchors.top: modeList.bottom
            anchors.topMargin: root.theme.spacingTokens.sm
            text: DisplayProjectionState.error
            color: root.theme.error
            wrapMode: Text.WordWrap
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.typeTokens.meta
        }

        Text {
            visible: !DisplayProjectionState.error.length && !DisplayProjectionState.busy
            anchors.left: modeList.left
            anchors.right: modeList.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.theme.popupInsets.md
                text: "↑/↓ navegar · Enter aplicar · Esc fechar"
            color: root.theme.surfaceVariantForeground
            horizontalAlignment: Text.AlignRight
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.typeTokens.meta
        }

        Row {
            visible: DisplayProjectionState.busy
            anchors.left: modeList.left
            anchors.right: modeList.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.theme.popupInsets.md

            Text {
                text: "Aplicando modo de tela…"
                color: root.theme.surfaceVariantForeground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
            }
        }
    }

    PopupOutsideClick {
        popupWindow: root
        onDismissed: DisplayProjectionState.close()
    }
}
