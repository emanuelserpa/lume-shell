pragma ComponentBehavior: Bound

import QtQuick
import qs.components

// Etapa 4 do fatiamento do Spotlight: painel de prévia do clipboard.
// Visual puro: recebe o resultado selecionado e o controlador, emite
// deleteRequested/pasteRequested/openImageRequested. O Spotlight continua dono do layout
// geral e da seleção.
Item {
    id: root

    required property var themeColors
    property var result: null
    property var store: null
    property bool active: false
    property string displayedItemId: ""
    readonly property var resultPayload: root.result?.payload ?? ({})
    readonly property string resolvedThumbnail: {
        const clipId = root.resultPayload.clipId
        const mapped = root.store && root.store.thumbs && clipId !== undefined && clipId !== null
            ? String(root.store.thumbs[String(clipId)] ?? "")
            : ""
        return mapped.length > 0 ? mapped : String(root.resultPayload.thumbnail ?? "")
    }
    readonly property bool selectedImage: root.result !== null
                                          && root.result.kind === "clipboard"
                                          && root.resultPayload.clipType === "image"

    signal deleteRequested()
    signal pasteRequested()
    signal openImageRequested()

    readonly property color launcherForeground: root.themeColors.surfaceForeground
    readonly property color launcherSecondary: root.themeColors.surfaceVariantForeground
    readonly property color launcherMuted: root.themeColors.surfaceVariantForeground
    readonly property color launcherPrimary: root.themeColors.primary

    visible: root.active

    onResultChanged: {
        const nextId = result && result.kind === "clipboard"
                       ? String(result.payload?.clipId ?? "") : ""
        if (displayedItemId !== nextId)
            previewFlickable.contentY = 0
        displayedItemId = nextId
    }

        // Preview Header
        Item {
            id: previewHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 28

            // Left: Badge & Info
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: headerActions.left
                anchors.rightMargin: root.themeColors.spacingTokens.md
                spacing: root.themeColors.spacingTokens.md
                clip: true

                // Badge
                Rectangle {
                    id: badgePill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: badgeText.implicitWidth + 12
                    radius: root.themeColors.radiusSm
                    visible: root.result !== null && root.result.kind === "clipboard"

                    readonly property string cType: root.result ? String(root.resultPayload.clipType ?? "text") : "text"
                    readonly property string cIcon: root.result ? String(root.resultPayload.icon ?? "") : ""

                    color: root.themeColors.withAlpha(root.themeColors.primary, 0.12)
                    border.width: 0
                    border.color: root.themeColors.outlineVariant

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: {
                            if (!root.result || root.result.kind !== "clipboard")
                                return ""
                            if (root.resultPayload.clipType === "image")
                                return "IMAGEM"
                            if (root.resultPayload.icon === "󰌷")
                                return "LINK"
                            if (root.resultPayload.icon === "󰘐")
                                return "CÓDIGO"
                            return "TEXTO"
                        }
                        color: {
                            if (!root.result || root.result.kind !== "clipboard")
                                return root.launcherSecondary
                            return root.themeColors.primary
                        }
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.spotlightLabelFontSize
                        font.weight: Font.Bold
                    }
                }

                // Metadata (lines, chars)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.result !== null && root.result.kind === "clipboard"
                    text: {
                        if (!root.result) return ""
                        if (root.resultPayload.clipType === "image") {
                            return String(root.resultPayload.mime || "Imagem")
                        }
                        const lines = root.resultPayload.lineCount ?? 1
                        const chars = root.resultPayload.charCount ?? 0
                        return lines > 1
                            ? (lines + " linhas · " + chars + " caracteres")
                            : (chars + " caracteres")
                    }
                    color: root.launcherSecondary
                    opacity: 0.80
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                    elide: Text.ElideRight
                }
            }

            // Right: Item-scoped feedback & delete pill
            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.themeColors.spacingTokens.sm
                visible: root.result !== null && root.result.kind === "clipboard"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.store.restoreError.length > 0
                    text: root.store.restoreError
                    color: root.themeColors.error
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                }

                Rectangle {
                    id: deletePill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    width: deleteRow.implicitWidth + 14
                    radius: root.themeColors.radiusSm
                    color: deleteMouse.containsMouse
                           ? root.themeColors.withAlpha(root.themeColors.error, 0.14)
                           : "transparent"

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        enabled: !root.store.deleteRunning
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.deleteRequested()
                    }

                    Row {
                        id: deleteRow
                        anchors.centerIn: parent
                        spacing: root.themeColors.spacingTokens.xs

                        TablerIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            iconName: "dashboard-trash"
                            iconColor: deleteMouse.containsMouse ? root.themeColors.error : root.launcherMuted
                            opacity: deleteMouse.containsMouse ? 1.0 : 0.72
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.store.deleteRunning ? "Removendo…" : "Remover"
                            color: deleteMouse.containsMouse ? root.themeColors.error : root.launcherMuted
                            opacity: deleteMouse.containsMouse ? 1.0 : 0.72
                            font.family: root.themeColors.fontFamily
                            font.pixelSize: root.themeColors.spotlightLabelFontSize
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        // Preview Card Body
        Rectangle {
            id: previewBodyCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: previewHeader.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: root.themeColors.spacingTokens.sm
            radius: root.themeColors.radiusMd
            color: root.themeColors.withAlpha(root.themeColors.heroBackdropStart, 0.55)
            border.width: 1
            border.color: root.themeColors.glassBorderSubtle
            clip: true

            // Empty state
            EmptyState {
                anchors.centerIn: parent
                visible: !root.result || root.result.kind !== "clipboard"
                theme: root.themeColors
                title: "Nenhum item selecionado"
                titleColor: root.launcherMuted
                titleSize: root.themeColors.spotlightBodyFontSize
            }

            // Image Preview
            Image {
                id: previewImage
                anchors.fill: parent
                anchors.margins: 12
                visible: root.result !== null
                         && root.result.kind === "clipboard"
                         && root.resultPayload.clipType === "image"
                source: visible ? root.resolvedThumbnail : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                sourceSize.width: 840
                sourceSize.height: 560
            }

            // Text Preview
            Flickable {
                id: previewFlickable
                anchors.fill: parent
                anchors.margins: 12
                visible: root.result !== null
                         && root.result.kind === "clipboard"
                         && root.resultPayload.clipType !== "image"
                contentWidth: width
                contentHeight: previewContent.paintedHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function scrollWheel(event) {
                    wheelKinetic.handle(event)
                }

                WheelKinetic {
                    id: wheelKinetic
                    scrollTarget: previewFlickable
                }

                TextEdit {
                    id: previewContent
                    width: previewFlickable.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: (root.result && root.resultPayload.fullText)
                          ? String(root.resultPayload.fullText)
                          : (root.result ? String(root.result.title ?? "") : "")
                    color: root.launcherForeground
                    font.family: root.themeColors.monoFontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                    selectionColor: root.themeColors.withAlpha(root.launcherPrimary, 0.35)
                    selectedTextColor: root.themeColors.surfaceForeground

                    WheelHandler {
                        target: null
                        blocking: true
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            previewFlickable.scrollWheel(event)
                        }
                    }
                }
            }

            // Scroll track for long text
            ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: root.themeColors.spacingTokens.tiny
                anchors.top: parent.top
                anchors.topMargin: root.themeColors.spacingTokens.xs
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.themeColors.spacingTokens.xs
                target: previewFlickable
                theme: root.themeColors
                wheelController: wheelKinetic
                thumbColor: root.launcherSecondary
                idleOpacity: 0.35
                hoverOpacity: 0.8
                rightInset: 2
            }

        }
    }
