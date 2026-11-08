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

                    color: root.themeColors.glassCardSurface
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
                            return root.themeColors.surfaceVariantForeground
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
                    opacity: 0.75
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                    elide: Text.ElideRight
                }
            }

            // Right: Action Buttons (Delete & Paste)
            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.rightMargin: captureToggle.visible ? root.themeColors.spacingTokens.sm : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.themeColors.spacingTokens.sm
                visible: root.result !== null && root.result.kind === "clipboard"

                // Error text if any
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.store.restoreError.length > 0
                    text: root.store.restoreError
                    color: root.themeColors.error
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                }

                // Delete Hint / Clickable Action
                Text {
                    id: deleteHint
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆴 Del"
                    color: deleteMouse.containsMouse ? root.themeColors.error : root.launcherMuted
                    opacity: deleteMouse.containsMouse ? 1.0 : 0.45
                    font.family: root.themeColors.nerdFontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteRequested()
                    }
                }

                // Separator bullet
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    color: root.launcherMuted
                    opacity: 0.35
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightLabelFontSize
                }

                // Paste Hint / Clickable Action
                Text {
                    id: pasteHint
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.store.restoreRunning || root.store.deleteRunning)
                          ? (root.store.restoreRunning ? "Restaurando…" : "Removendo…")
                          : "↵ Colar"
                    color: pasteMouse.containsMouse ? root.launcherPrimary : root.launcherMuted
                    opacity: pasteMouse.containsMouse ? 1.0 : 0.65
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize

                    MouseArea {
                        id: pasteMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pasteRequested()
                    }
                }

                Text {
                    id: openImageHint
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.selectedImage
                    text: root.store.imageOpenRunning ? "Abrindo imagem…" : "Ctrl+↵ Abrir imagem"
                    color: openImageMouse.containsMouse ? root.launcherPrimary : root.launcherMuted
                    opacity: openImageMouse.containsMouse ? 1.0 : 0.65
                    font.family: root.themeColors.fontFamily
                    font.pixelSize: root.themeColors.spotlightBodyFontSize

                    MouseArea {
                        id: openImageMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openImageRequested()
                    }
                }
            }

            Text {
                id: captureToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.store.capturePauseKnown
                text: root.store.captureControlRunning
                      ? "Salvando…"
                      : (root.store.captureControlError.length > 0
                         ? "Erro · tentar"
                         : (root.store.capturePaused ? "▶ Retomar" : "Ⅱ Pausar"))
                color: root.store.captureControlError.length > 0
                       ? root.themeColors.error
                       : (captureMouse.containsMouse
                          ? root.themeColors.primary : root.launcherMuted)
                opacity: captureMouse.containsMouse ? 1.0 : 0.75
                font.family: root.themeColors.fontFamily
                font.pixelSize: root.themeColors.spotlightBodyFontSize

                MouseArea {
                    id: captureMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: !root.store.captureControlRunning
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        const desired = root.store.captureControlError.length > 0
                            ? root.store.capturePaused : !root.store.capturePaused
                        root.store.setCapturePaused(desired)
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
            anchors.topMargin: root.themeColors.spacingTokens.xs
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
                source: visible && root.result && root.resultPayload.thumbnail
                        ? root.resultPayload.thumbnail
                        : ""
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
