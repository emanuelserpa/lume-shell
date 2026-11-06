pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
    id: root

    required property var themeColors
    required property var modeOptions

    property string contextText: ""
    property string primaryText: ""
    property string secondaryText: ""
    property bool hasActions: false
    property bool arrowActions: false
    property bool hasSelection: false
    property bool showCategories: false
    property bool showModes: false
    property bool categoryMenuOpen: false
    property bool modeMenuOpen: false
    property int modeMenuIndex: 0

    signal primaryClicked()
    signal secondaryClicked()
    signal actionsClicked()
    signal categoryClicked()
    signal modesClicked()

    readonly property var actionItems: {
        const items = []
        if (primaryText.length > 0)
            items.push({id: "primary", key: "↵", label: primaryText})
        if (secondaryText.length > 0)
            items.push({id: "secondary", key: "Ctrl+↵", label: secondaryText})
        if (hasActions)
            items.push({id: "actions", key: arrowActions ? "→" : "Ctrl+K", label: "Ações"})
        if (showModes)
            items.push({id: "modes", key: "", label: "Modos  Ctrl+/"})
        return items
    }

    width: parent ? parent.width : 0
    height: 34

    Row {
        id: leftContent
        anchors.left: parent.left
        anchors.leftMargin: root.themeColors.spacingTokens.xxl
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.themeColors.spacingTokens.md

        Item {
            id: categoryButton
            visible: root.showCategories
            width: visible ? categoryLabel.implicitWidth + 18 : 0
            height: 26

            Rectangle {
                anchors.fill: parent
                radius: root.themeColors.radiusSm
                color: categoryHover.hovered
                       ? root.themeColors.stateLayer(root.themeColors.surfaceForeground, "hover")
                       : "transparent"
            }

            HoverHandler {
                id: categoryHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler { onTapped: root.categoryClicked() }

            Text {
                id: categoryLabel
                anchors.centerIn: parent
                text: root.categoryMenuOpen ? "Esc  Voltar" : "←  Categorias"
                color: categoryHover.hovered
                       ? root.themeColors.surfaceForeground
                       : root.themeColors.surfaceVariantForeground
                font.family: root.themeColors.fontFamily
                font.pixelSize: root.themeColors.spotlightLabelFontSize
            }
        }

        Text {
            visible: root.contextText.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.contextText
            color: root.themeColors.surfaceVariantForeground
            font.family: root.themeColors.fontFamily
            font.pixelSize: root.themeColors.spotlightLabelFontSize
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Row {
        id: rightActions
        anchors.right: parent.right
        anchors.rightMargin: root.themeColors.spacingTokens.xxl
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.themeColors.spacingTokens.xs

        Repeater {
            model: root.actionItems

            delegate: Item {
                id: footerAction
                required property var modelData
                required property int index
                readonly property bool selected: modelData.id === "modes" && root.modeMenuOpen

                width: actionLabel.implicitWidth + 20
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: root.themeColors.radiusSm
                    color: footerAction.selected
                           ? root.themeColors.primaryContainer
                           : (actionHover.hovered
                              ? root.themeColors.stateLayer(root.themeColors.surfaceForeground, "hover")
                              : "transparent")
                }

                HoverHandler {
                    id: actionHover
                    enabled: footerAction.modelData.id !== "primary" || root.hasSelection
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: footerAction.modelData.id !== "primary" || root.hasSelection
                    onTapped: {
                        switch (footerAction.modelData.id) {
                        case "primary": root.primaryClicked(); break
                        case "secondary": root.secondaryClicked(); break
                        case "actions": root.actionsClicked(); break
                        case "modes": root.modesClicked(); break
                        }
                    }
                }

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: (footerAction.modelData.key.length > 0
                           ? footerAction.modelData.key + "  " : "") + footerAction.modelData.label
                    color: footerAction.selected
                           ? root.themeColors.primaryContainerForeground
                           : (actionHover.hovered
                              ? root.themeColors.surfaceForeground
                              : root.themeColors.surfaceVariantForeground)
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                    font.weight: footerAction.selected ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    Rectangle {
        id: modeMenu
        visible: root.modeMenuOpen
        z: 10
        width: 220
        height: Math.min(modeRows.implicitHeight + 12, 300)
        anchors.right: parent.right
        anchors.rightMargin: root.themeColors.spacingTokens.xxl
        anchors.bottom: parent.top
        anchors.bottomMargin: root.themeColors.spacingTokens.smPlus
        radius: root.themeColors.radiusPopup
        color: root.themeColors.popupBackground
        border.width: 1
        border.color: root.themeColors.borderPopup
        clip: true

        Column {
            id: modeRows
            anchors.fill: parent
            anchors.margins: 6
            spacing: root.themeColors.spacingTokens.tiny

            Repeater {
                model: root.modeOptions

                delegate: PopupListRow {
                    id: modeRow
                    required property int index
                    required property var modelData

                    width: modeRows.width
                    rowHeight: 31
                    cornerRadius: root.themeColors.radiusSm
                    theme: root.themeColors
                    active: index === root.modeMenuIndex
                    activeColor: root.themeColors.primaryContainer
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    activeBorderWidth: 0
                    leadingIcon: modelData.prefix
                    leadingIconPixelSize: root.themeColors.typeTokens.body
                    leadingIconColor: modeRow.active
                                     ? root.themeColors.primary
                                     : root.themeColors.surfaceVariantForeground
                    title: modelData.label
                    titleColor: modeRow.active
                                ? root.themeColors.primaryContainerForeground
                                : root.themeColors.surfaceForeground
                    titlePixelSize: root.themeColors.typeTokens.body

                    interactionHandlers: TapHandler {
                        onTapped: root.modeSelected(modeRow.modelData.prefix)
                    }
                }
            }
        }
    }

    signal modeSelected(string prefix)
}
