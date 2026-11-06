pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "SpotlightActionLogic.js" as ActionLogic

// Painel de Detalhes & Ações do Spotlight inspirado no Raycast (Detail & Actions)
// Exibido na coluna direita quando Ctrl+K é acionado, integrando metadados e ações.
Item {
    id: root

    required property var themeColors
    property var actions: []
    property int currentIndex: 0
    property var targetItem: null
    property string categoryLabel: ""
    signal actionChosen(string actionId)

    // Filtro digitado com o painel aberto + agrupamento por seção.
    property string filterText: ""
    readonly property var groupOrder: ["Principal", "Copiar", "Ações", "Gerenciar"]
    readonly property var panelEntries: ActionLogic.groupedActions(
        root.actions, root.groupOrder, root.filterText)

    function entryActionAt(idx) {
        return ActionLogic.actionAt(root.panelEntries, idx)
    }

    function actionAt(idx) {
        return root.entryActionAt(idx)
    }

    function panelMove(d) {
        return ActionLogic.moveIndex(root.panelEntries, root.currentIndex, d)
    }

    readonly property string kind: String(root.targetItem?.kind ?? "")
    readonly property var targetPayload: root.targetItem?.payload ?? ({})

    readonly property string kindLabel: {
        switch (root.kind) {
        case "app": return "Aplicativo"
        case "file": return "Arquivo"
        case "window": return "Janela"
        case "clipboard": return "Área de Transferência"
        case "calc": return "Cálculo"
        case "command": return "Comando"
        case "theme_select": return "Tema"
        case "emoji": return "Emoji"
        case "system": return "Sistema"
        case "kill": return "Encerrar"
        case "close_window": return "Encerrar"
        default: return "Item"
        }
    }

    readonly property string iconGlyph: {
        switch (root.kind) {
        case "window": return "󰖯"
        case "file": return "󰈔"
        case "command": return "󰆍"
        case "calc": return "󰃬"
        case "clipboard": return "󰅍"
        case "theme_select": return "󰔎"
        case "emoji": return "󰞅"
        case "system": return "󰒓"
        case "kill": return "󰅖"
        case "close_window": return "󰅖"
        default: return "󰌌"
        }
    }

    readonly property string detailSecondary: {
        if (!root.targetItem) return ""
        if (root.targetPayload.usageCount && root.targetPayload.usageCount > 0)
            return "Usado " + root.targetPayload.usageCount + " vezes no launcher"
        if (root.targetPayload.workspaceName || root.targetPayload.workspaceId)
            return "Workspace: " + (root.targetPayload.workspaceName ?? root.targetPayload.workspaceId)
        return ""
    }

    Column {
        anchors.fill: parent
        spacing: root.themeColors.spacingTokens.xl

        // =====================================================================
        // HEADER: Ícone grande + Nome do item + Badge de Categoria + Subtítulo
        // =====================================================================
        Row {
            width: parent.width
            height: 48
            spacing: root.themeColors.spacingTokens.xl

            // Container do Ícone (44x44)
            Rectangle {
                width: 44
                height: 44
                radius: root.themeColors.radiusXl
                color: root.themeColors.glassCardSurface
                border.width: 1
                border.color: root.themeColors.borderSubtle
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                IconImage {
                    id: headerAppIcon
                    anchors.centerIn: parent
                    width: root.themeColors.spotlightIconTokens.detail
                    height: root.themeColors.spotlightIconTokens.detail
                    visible: (root.kind === "app" || root.kind === "window")
                             && String(root.targetPayload.icon ?? "").length > 0
                    source: visible ? Quickshell.iconPath(root.targetPayload.icon, true) : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !headerAppIcon.visible
                    text: root.iconGlyph
                    color: root.themeColors.primary
                    font.family: root.themeColors.nerdFontFamily
                    font.pixelSize: root.themeColors.spotlightIconTokens.detail
                }
            }

            // Textos do Topo
            Column {
                width: parent.width - 56
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.themeColors.spacingTokens.tight

                Row {
                    width: parent.width
                    spacing: root.themeColors.spacingTokens.md

                    Text {
                        text: String(root.targetItem?.title ?? "")
                        color: root.themeColors.surfaceForeground
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.spotlightTitleFontSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, parent.width - categoryBadge.width - 8)
                    }

                    Rectangle {
                        id: categoryBadge
                        height: 18
                        width: catText.implicitWidth + 10
                        radius: root.themeColors.radiusSm
                        color: root.themeColors.glassCardSurface
                        border.width: 0
                        border.color: root.themeColors.outlineVariant
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: root.kind === "app" && root.categoryLabel.length > 0
                                  ? root.kindLabel + " · " + root.categoryLabel
                                  : root.kindLabel
                            color: root.themeColors.surfaceVariantForeground
                            font.family: root.themeColors.fontFamily
                            font.pixelSize: root.themeColors.spotlightLabelFontSize
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: String(root.targetItem?.subtitle ?? "")
                    color: root.themeColors.surfaceVariantForeground
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }
        }

        // =====================================================================
        // CARD DE METADADOS: só uso/workspace (sem IDs internos nem comandos crus;
        // o comando continua disponível em "Copiar comando")
        // =====================================================================
        Rectangle {
            width: parent.width
            height: metaCol.implicitHeight + 16
            radius: root.themeColors.radiusLg
            color: root.themeColors.glassCardSurface
            border.width: 1
            border.color: root.themeColors.borderSubtle
            visible: root.detailSecondary.length > 0

            Column {
                id: metaCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: root.themeColors.spacingTokens.sm

                // Linha única: uso / workspace
                Row {
                    width: parent.width
                    spacing: root.themeColors.spacingTokens.sm
                    visible: root.detailSecondary.length > 0

                    Text {
                        text: "󰄲"
                        color: root.themeColors.primary
                        font.family: root.themeColors.nerdFontFamily
                        font.pixelSize: root.themeColors.spotlightBodyFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - 20
                        text: root.detailSecondary
                        color: root.themeColors.surfaceVariantForeground
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.spotlightBodyFontSize
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // =====================================================================
        // SEPARADOR & RÓTULO DA SEÇÃO DE AÇÕES
        // =====================================================================
        Row {
            width: parent.width
            spacing: root.themeColors.spacingTokens.md

            Text {
                text: "Ações"
                color: root.themeColors.surfaceVariantForeground
                font.family: root.themeColors.fontFamily
                font.pixelSize: root.themeColors.spotlightLabelFontSize
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: parent.width - 130
                height: 1
                color: root.themeColors.borderSubtle
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // =====================================================================
        // LISTA DE AÇÕES (REFINADA: SEM WIREFRAME, COM ÍCONES E KEYCAPS)
        // =====================================================================
        Column {
            width: parent.width
            spacing: root.themeColors.spacingTokens.xs

            Repeater {
                model: root.panelEntries

                delegate: Rectangle {
                    id: actionRow
                    required property var modelData
                    required property int index

                    readonly property var action: modelData.action ?? modelData

                    readonly property bool isSelected: index === root.currentIndex
                    readonly property string actionIcon: String(action.icon ?? "󰌌")
                    readonly property string actionHint: String(action.hint ?? "")
                    readonly property bool isDestructive: action.id === "close" || action.id === "delete"

                    width: parent.width
                    height: 36
                    radius: root.themeColors.radiusSm
                    color: isSelected
                           ? (isDestructive ? root.themeColors.errorContainer : root.themeColors.glassActiveSurface)
                           : (rowHov.hovered
                              ? root.themeColors.stateLayer(root.themeColors.surfaceForeground, "hover")
                              : "transparent")
                    border.width: 0
                    border.color: root.themeColors.outlineVariant

                    // Indicador vertical sutil à esquerda no item selecionado
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: root.themeColors.spacingTokens.tiny
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 1.5
                        color: root.themeColors.primary
                        visible: actionRow.isSelected
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: root.themeColors.spacingTokens.xl
                        anchors.rightMargin: root.themeColors.spacingTokens.lg
                        spacing: root.themeColors.spacingTokens.lg

                        // Ícone da ação
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionRow.actionIcon
                            color: actionRow.isDestructive
                                   ? root.themeColors.error
                                   : (actionRow.isSelected ? root.themeColors.primary : root.themeColors.surfaceVariantForeground)
                            font.family: root.themeColors.nerdFontFamily
                            font.pixelSize: root.themeColors.spotlightIconTokens.action
                        }

                        // Título da ação
                        Text {
                            width: parent.width - 24 - (hintBadge.visible ? (hintBadge.width + 10) : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: (actionRow.action.title ?? "")
                            color: actionRow.isSelected
                                   ? (actionRow.isDestructive
                                      ? root.themeColors.errorContainerForeground
                                      : root.themeColors.primaryContainerForeground)
                                   : root.themeColors.surfaceVariantForeground
                            font.family: root.themeColors.fontFamily
                            font.pixelSize: root.themeColors.spotlightBodyFontSize
                            font.weight: actionRow.isSelected ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        // Keycap badge de atalho (↵, Ctrl+↵)
                        Rectangle {
                            id: hintBadge
                            height: 20
                            width: hintText.implicitWidth + 12
                            radius: root.themeColors.radiusSm
                            anchors.verticalCenter: parent.verticalCenter
                            visible: actionRow.actionHint.length > 0
                            color: actionRow.isSelected
                                   ? (actionRow.isDestructive ? root.themeColors.error : root.themeColors.primary)
                                   : root.themeColors.glassCardSurface
                            border.width: 0
                            border.color: root.themeColors.outlineVariant

                            Text {
                                id: hintText
                                anchors.centerIn: parent
                                text: actionRow.actionHint
                                color: actionRow.isSelected
                                       ? (actionRow.isDestructive ? root.themeColors.errorForeground : root.themeColors.primaryForeground)
                                       : root.themeColors.surfaceVariantForeground
                                font.family: root.themeColors.monoFontFamily
                                font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    HoverHandler {
                        id: rowHov
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                root.currentIndex = actionRow.index
                        }
                    }

                    TapHandler {
                        onTapped: root.actionChosen(actionRow.action.id)
                    }
                }
            }
        }

        // =====================================================================
        // RODAPÉ: GUIA DE TECLADO SUTIL
        // =====================================================================
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.centerIn: parent
                spacing: root.themeColors.spacingTokens.md

                Text {
                    text: "↑↓ navegar"
                    color: root.themeColors.surfaceVariantForeground
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }

                Text {
                    text: "·"
                    color: root.themeColors.borderSubtle
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }

                Text {
                    text: "Enter executar"
                    color: root.themeColors.surfaceVariantForeground
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }

                Text {
                    text: "·"
                    color: root.themeColors.borderSubtle
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }

                Text {
                    text: "Esc fechar"
                    color: root.themeColors.surfaceVariantForeground
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }
            }
        }
    }
}
