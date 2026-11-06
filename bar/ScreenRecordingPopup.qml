pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property bool recording: false
    property bool hasAudio: false
    property string audioMode: "none"
    property bool busy: false
    property string elapsedText: "0:00"
    property string errorText: ""
    property string savedPath: ""

    signal startRequested(string mode, string audioMode)
    signal stopRequested()

    function audioModeSelected(mode) {
        return root.audioMode === mode || root.audioMode === "both"
    }

    function toggleAudioMode(mode) {
        const microphone = root.audioModeSelected("microphone")
        const system = root.audioModeSelected("system")
        const nextMicrophone = mode === "microphone" ? !microphone : microphone
        const nextSystem = mode === "system" ? !system : system

        root.audioMode = nextMicrophone
                ? (nextSystem ? "both" : "microphone")
                : (nextSystem ? "system" : "none")
    }

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type
    implicitWidth: 302
    implicitHeight: popupContent.implicitHeight + root.theme.popupInsets.outer * 2
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {

        if (visible) card.forceActiveFocus()
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        Keys.onEscapePressed: root.visible = false

        Column {
            id: popupContent
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.outer
            spacing: root.theme.spacingTokens.smPlus

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                leadingTablerIcon: root.recording && root.hasAudio ? "bar-record-audio" : "bar-record"
                leadingIconColor: root.recording ? root.theme.red : root.theme.primary
                iconBoxSize: 28
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lgPlus
                contentGap: root.theme.spacingTokens.smPlus
                headerHeight: 44
                title: root.recording ? ("Gravando tela  " + root.elapsedText) : "Gravar tela"
                titlePixelSize: root.theme.typeTokens.titleMedium
                titleWeight: Font.Bold
                subtitle: root.recording
                          ? (root.hasAudio ? "Vídeo e áudio serão salvos em Vídeos." : "O vídeo será salvo em Vídeos.")
                          : "Escolha o que deseja gravar"
                subtitleColor: root.theme.surfaceVariantForeground
                subtitlePixelSize: root.theme.typeTokens.body
                subtitleSpacing: root.theme.spacingTokens.smPlus
                titleColor: root.recording ? root.theme.red : root.theme.foreground
            }

            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs
                visible: !root.recording
                opacity: root.busy ? 0.45 : 1

                Text {
                    text: "Áudio"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    font.weight: Font.DemiBold
                }

                Grid {
                    width: parent.width
                    columns: 2
                    spacing: root.theme.spacingTokens.xs
                    Repeater {
                        model: [
                            {mode: "microphone", label: "Microfone", tablerIcon: "microphone"},
                            {mode: "system", label: "Som do sistema", tablerIcon: "bar-volume"}
                        ]
                        delegate: Rectangle {
                            id: audioChoice
                            required property var modelData
                            width: (parent.width - root.theme.spacingTokens.xs) / 2
                            height: 36
                            radius: root.theme.radiusSm
                            color: root.audioModeSelected(modelData.mode) ? root.theme.withAlpha(root.theme.primary, 0.18) : root.theme.glassCardSurface
                            border.width: 1
                            border.color: root.audioModeSelected(modelData.mode) ? root.theme.primary : root.theme.adaptiveCardBorder
                            opacity: root.busy ? 0.45 : 1

                            Row {
                                anchors.centerIn: parent
                                spacing: root.theme.spacingTokens.xs
                                TablerIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.theme.iconTokens.smPlus
                                    height: root.theme.iconTokens.smPlus
                                    iconName: audioChoice.modelData.tablerIcon
                                    iconColor: root.audioModeSelected(audioChoice.modelData.mode) ? root.theme.primary : root.theme.foreground
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: audioChoice.modelData.label
                                    color: root.audioModeSelected(audioChoice.modelData.mode) ? root.theme.primary : root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    font.weight: root.audioModeSelected(audioChoice.modelData.mode) ? Font.DemiBold : Font.Normal
                                }
                            }
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: audioChoice.modelData.label
                            Accessible.checked: root.audioModeSelected(audioChoice.modelData.mode)
                            TapHandler {
                                enabled: !root.busy
                                onTapped: root.toggleAudioMode(audioChoice.modelData.mode)
                            }
                        }
                    }
                }
            }

            Repeater {
                visible: !root.recording
                model: [
                    {mode: "window", tablerIcon: "device-desktop", title: "Janela", detail: "Escolher uma janela visível"},
                    {mode: "screen", tablerIcon: "device-desktop", title: "Tela inteira", detail: "Monitor em foco"},
                    {mode: "selection", tablerIcon: "bar-record", title: "Seleção", detail: "Marcar uma área na tela"}
                ]


                delegate: PopupListRow {
                    id: recordingTargetDelegate
                    theme: root.theme
                    required property var modelData
                    rowHeight: 38
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: !root.recording && !root.busy
                    idleColor: root.theme.glassPanelSurface
                    hoverColor: root.theme.glassHoverSurface
                    opacity: root.recording || root.busy ? 0.45 : 1
                    leadingTablerIcon: recordingTargetDelegate.modelData.tablerIcon
                    leadingIconColor: root.theme.primary
                    leadingIconPixelSize: root.theme.iconTokens.lgPlus
                    title: recordingTargetDelegate.modelData.title
                    subtitle: recordingTargetDelegate.modelData.detail
                    subtitleColor: root.theme.surfaceVariantForeground
                    interactionHandlers: TapHandler {
                        enabled: !root.recording && !root.busy
                        onTapped: root.startRequested(recordingTargetDelegate.modelData.mode, root.audioMode)
                    }

                }
            }

            Rectangle {
                width: parent.width
                height: 30
                radius: root.theme.radiusSm
                visible: root.recording
                color: stopHover.hovered ? root.theme.red : root.theme.glassCardSurface
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Finalizando…" : "Parar gravação"
                    color: stopHover.hovered ? root.theme.backgroundOpaque : root.theme.red
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.body
                    font.weight: Font.DemiBold
                }
                HoverHandler { id: stopHover }
                TapHandler { enabled: !root.busy; onTapped: root.stopRequested() }
            }

            Text {
                width: parent.width
                visible: root.errorText.length > 0 || root.savedPath.length > 0
                text: root.errorText.length > 0 ? root.errorText : "Salvo: " + root.savedPath
                color: root.errorText.length > 0 ? root.theme.red : root.theme.green
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                elide: Text.ElideMiddle
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }
}
