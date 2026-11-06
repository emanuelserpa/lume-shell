pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.controlcenter
import qs.services

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var sink: null
    property var source: null
    property var outputs: []
    property var inputs: []
    property var streams: []
    property bool effectsPresetBusy: false

    signal settingsRequested()

    readonly property real maxAllowedHeight: Math.max(300, (target?.Screen?.height ?? 900) - 60)

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 380
    implicitHeight: Math.min(820, maxAllowedHeight,
                             contentColumn.implicitHeight + root.theme.popupInsets.large * 2)
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true


    onVisibleChanged: {
        EasyEffectsState.popupOpen = visible
        if (visible) {
            card.forceActiveFocus()
            EasyEffectsState.refresh()
        }
    }

    function cycleEffectsPreset(pipeline, direction) {
        const presets = pipeline === "output" ? EasyEffectsState.outputPresets : EasyEffectsState.inputPresets
        if (!presets || presets.length === 0) return
        const current = pipeline === "output" ? EasyEffectsState.outputPreset : EasyEffectsState.inputPreset
        let index = presets.indexOf(current)
        index = (index + direction + presets.length) % presets.length
        EasyEffectsState.loadPreset(pipeline, presets[index])
    }

    function nodeName(node, fallback) {
        if (!node) return fallback
        const properties = node.properties || {}
        const profile = String(properties["device.profile.description"] || "")
        const hdmiMatch = profile.match(/HDMI\s*\/\s*DisplayPort\s+(\d+)/i)
        if (hdmiMatch) return "HDMI/DP " + hdmiMatch[1]

        const normalizedProfile = profile.toLowerCase()
        if (normalizedProfile.includes("headphones")) return "Fones"
        if (normalizedProfile.includes("speaker")) return "Alto-falantes"
        if (normalizedProfile.includes("digital microphone")) return "Microfone digital"
        if (normalizedProfile.includes("stereo microphone")) return "Microfone estéreo"

        return node.description || node.nickname || node.name || fallback
    }

    function streamName(node) {
        if (!node) return "Aplicativo"
        const p = (node.ready && node.properties) ? node.properties : (node.properties || {})
        const app = p["application.name"] || node.description || p["node.name"] || node.name || p["media.name"]
        if (app && app.length > 0) return String(app)
        return "Aplicativo"
    }

    function streamDetail(node) {
        if (!node) return ""
        const p = node.properties || {}
        const media = String(p["media.name"] || "").trim()
        const app = streamName(node)
        const generic = ["audiostream", "audio stream", "playback", "output"]
        if (!media || media.toLowerCase() === app.toLowerCase()
                || generic.includes(media.toLowerCase())) return ""
        return media
    }

    function streamIcon(node) {
        const name = streamName(node).toLowerCase()
        if (name.includes("firefox")) return "󰈹"
        if (name.includes("chrome") || name.includes("chromium") || name.includes("brave")) return "󰊯"
        if (name.includes("spotify")) return "󰓇"
        if (name.includes("discord") || name.includes("vesktop") || name.includes("webcord")) return "󰙯"
        if (name.includes("telegram")) return "󰅣"
        if (name.includes("mpv") || name.includes("vlc") || name.includes("video") || name.includes("player")) return "󰕼"
        if (name.includes("steam") || name.includes("game")) return "󰊴"
        return "󰓃"
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Keys.onEscapePressed: root.visible = false

        Flickable {
            id: audioContentFlick
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.large
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true

            WheelKinetic { scrollTarget: audioContentFlick }

            Column {
                id: contentColumn
                width: audioContentFlick.width
                spacing: root.theme.spacingTokens.mdPlus

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 30
                horizontalInset: 0
                topInset: 0
                leadingTablerIcon: "bar-volume"
                iconBoxSize: 28
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lgPlus
                contentGap: root.theme.spacingTokens.smPlus
                title: "Mixer de áudio"
                titleWeight: Font.Bold

                PopupSettingsButton {
                    width: 26
                    height: 24
                    theme: root.theme
                    onClicked: root.settingsRequested()
                }

                Rectangle {
                    height: 18
                    width: 58
                    radius: root.theme.radiusSm
                    color: root.theme.glassCardSurface
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.border, 0.40)

                    Text {
                        anchors.centerIn: parent
                        text: "PipeWire"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // EASYEFFECTS -------------------------------------------------
            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                Row {
                    width: parent.width
                    height: 32
                    spacing: root.theme.spacingTokens.sm

                    Text {
                        width: parent.width - 58
                        anchors.verticalCenter: parent.verticalCenter
                        text: EasyEffectsState.available
                              ? (EasyEffectsState.bypassed ? "Efeitos desativados" : "Efeitos ativos")
                              : "EasyEffects indisponível"
                        color: EasyEffectsState.available ? root.theme.foreground : root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.bodyEmphasis
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MaterialSwitch {
                        width: 48
                        height: 32
                        theme: root.theme
                        accessibleLabel: "Ativar efeitos do EasyEffects"
                        checked: EasyEffectsState.available && !EasyEffectsState.bypassed
                        enabled: EasyEffectsState.available && !EasyEffectsState.busy
                        onClicked: EasyEffectsState.setBypassed(!checked)
                    }
                }

                PopupListRow {
                    id: outputPresetRow
                    theme: root.theme
                    width: parent.width
                    rowHeight: 38
                    leadingTablerIcon: "bar-volume"
                    title: EasyEffectsState.outputPreset || "Nenhum preset"
                    subtitle: "Saída · " + EasyEffectsState.outputPresets.length + " presets"
                    titleColor: root.theme.foreground
                    leadingIconColor: root.theme.primary
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    trailing: Component {
                        Row {
                            spacing: root.theme.spacingTokens.xs
                            PopupIconButton {
                                theme: root.theme
                                width: 24
                                height: 24
                                tablerIcon: "dashboard-chevron-left"
                                iconPixelSize: root.theme.iconTokens.smPlus
                                enabled: EasyEffectsState.available && !EasyEffectsState.busy && EasyEffectsState.outputPresets.length > 1
                                onClicked: root.cycleEffectsPreset("output", -1)
                            }
                            PopupIconButton {
                                theme: root.theme
                                width: 24
                                height: 24
                                tablerIcon: "dashboard-chevron-right"
                                iconPixelSize: root.theme.iconTokens.smPlus
                                enabled: EasyEffectsState.available && !EasyEffectsState.busy && EasyEffectsState.outputPresets.length > 1
                                onClicked: root.cycleEffectsPreset("output", 1)
                            }
                        }
                    }
                    interactionHandlers: TapHandler {
                        onTapped: EasyEffectsState.openWindow()
                    }
                }

                PopupListRow {
                    theme: root.theme
                    width: parent.width
                    rowHeight: 38
                    leadingTablerIcon: "microphone"
                    title: EasyEffectsState.inputPreset || "Padrão do microfone"
                    subtitle: "Entrada · " + EasyEffectsState.inputPresets.length + " presets"
                    titleColor: root.theme.foreground
                    leadingIconColor: root.theme.pink
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    trailing: Component {
                        Row {
                            spacing: root.theme.spacingTokens.xs
                            PopupIconButton {
                                theme: root.theme
                                width: 24
                                height: 24
                                tablerIcon: "dashboard-chevron-left"
                                iconPixelSize: root.theme.iconTokens.smPlus
                                enabled: EasyEffectsState.available && !EasyEffectsState.busy && EasyEffectsState.inputPresets.length > 1
                                onClicked: root.cycleEffectsPreset("input", -1)
                            }
                            PopupIconButton {
                                theme: root.theme
                                width: 24
                                height: 24
                                tablerIcon: "dashboard-chevron-right"
                                iconPixelSize: root.theme.iconTokens.smPlus
                                enabled: EasyEffectsState.available && !EasyEffectsState.busy && EasyEffectsState.inputPresets.length > 1
                                onClicked: root.cycleEffectsPreset("input", 1)
                            }
                        }
                    }
                    interactionHandlers: TapHandler {
                        onTapped: EasyEffectsState.openWindow()
                    }
                }

                Text {
                    visible: EasyEffectsState.error.length > 0 && EasyEffectsState.available
                    width: parent.width
                    text: EasyEffectsState.error
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // OUTPUT ------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 88
                radius: root.theme.radiusXl
                color: root.theme.adaptiveCardSurface
                border.width: 1
                border.color: root.theme.adaptiveCardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: root.theme.popupInsets.standard
                    spacing: root.theme.spacingTokens.mdPlus

                    Row {
                        width: parent.width
                        height: 34
                        spacing: root.theme.spacingTokens.mdPlus

                        Rectangle {
                            id: sinkMuteButton
                            width: 32
                            height: 32
                            radius: root.theme.radiusButton
                            color: sinkMuteHover.hovered
                                   ? root.theme.glassActiveSurface
                                   : root.theme.glassHoverSurface

                            TablerIcon {
                                anchors.centerIn: parent
                                width: root.theme.iconTokens.lgPlus
                                height: root.theme.iconTokens.lgPlus
                                iconName: root.sink?.audio?.muted ? "bar-volume-off" : "bar-volume"
                                iconColor: root.sink?.audio?.muted ? root.theme.red : root.theme.primary
                            }

                            HoverHandler { id: sinkMuteHover }
                            TapHandler {
                                onTapped: {
                                    if (root.sink?.audio)
                                        root.sink.audio.muted = !root.sink.audio.muted
                                }
                            }
                        }

                        Column {
                            width: parent.width - 41
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.micro

                            Text {
                                text: root.sink?.audio?.muted ? "Saída · mutada" : "Saída"
                                color: root.sink?.audio?.muted ? root.theme.red : root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                            }

                            Text {
                                width: parent.width
                                text: root.nodeName(root.sink, "Nenhuma saída")
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.subtitle
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: root.theme.spacingTokens.md

                        Item {
                            width: parent.width - 50
                            height: 24

                            SliderRow {
                                anchors.fill: parent
                                theme: root.theme
                                showIcon: false
                                showValue: false
                                wheelEnabled: false
                                thumbAlwaysVisible: true
                                value: root.sink?.audio ? root.sink.audio.volume : 0
                                maximum: 1.5
                                accent: root.theme.primary
                                available: Boolean(root.sink?.audio)
                                onValueRequested: function(value) {
                                    if (root.sink?.audio)
                                        root.sink.audio.volume = value
                                }
                            }
                        }

                        Text {
                            width: 42
                            text: root.sink?.audio
                                  ? Math.round(root.sink.audio.volume * 100) + "%"
                                  : "--%"
                            color: root.theme.offWhite
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.body
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // APLICATIVOS (Per-App Streams) --------------------------------
            Column {
                visible: root.streams.length > 0
                width: parent.width
                spacing: root.theme.spacingTokens.xsPlus

                Text {
                    text: "APLICATIVOS"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }

                Flickable {
                    id: streamFlick
                    width: parent.width
                    height: Math.min(130, streamList.implicitHeight)
                    contentWidth: width
                    contentHeight: streamList.implicitHeight
                    clip: true

                    WheelKinetic { scrollTarget: streamFlick }

                    Column {
                        id: streamList
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.streams

                            delegate: PopupListRow {
                                id: streamDelegate
                                theme: root.theme
                                required property var modelData

                                rowHeight: root.streamDetail(modelData) ? 64 : 52

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: root.theme.popupInsets.smallPlus
                                    spacing: root.streamDetail(streamDelegate.modelData) ? 2 : 4

                                    Row {
                                        width: parent.width
                                        height: 16
                                        spacing: root.theme.spacingTokens.sm

                                        Text {
                                            text: root.streamIcon(streamDelegate.modelData)
                                            color: root.theme.primary
                                            font.family: root.theme.nerdFontFamily
                                            font.pixelSize: root.theme.iconTokens.md
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            width: parent.width - 95
                                            text: root.streamName(streamDelegate.modelData)
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.body
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        // Mute toggle
                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: root.theme.radiusSm
                                            color: streamDelegate.modelData.audio?.muted ? root.theme.withAlpha(root.theme.red, 0.25) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            TablerIcon {
                                                anchors.centerIn: parent
                                                width: root.theme.iconTokens.sm
                                                height: root.theme.iconTokens.sm
                                                iconName: streamDelegate.modelData.audio?.muted ? "bar-volume-off" : "bar-volume"
                                                iconColor: streamDelegate.modelData.audio?.muted ? root.theme.red : root.theme.foreground
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    if (streamDelegate.modelData.audio)
                                                        streamDelegate.modelData.audio.muted = !streamDelegate.modelData.audio.muted
                                                }
                                            }
                                        }

                                        Text {
                                            width: 42
                                            text: streamDelegate.modelData.audio ? Math.round(streamDelegate.modelData.audio.volume * 100) + "%" : "--%"
                                            color: root.theme.offWhite
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.meta
                                            horizontalAlignment: Text.AlignRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        visible: root.streamDetail(streamDelegate.modelData).length > 0
                                        width: parent.width
                                        text: root.streamDetail(streamDelegate.modelData)
                                        color: root.theme.foreground
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.meta
                                        elide: Text.ElideRight
                                    }

                                    // Mini volume slider
                                    Item {
                                        width: parent.width
                                        height: 24

                                        SliderRow {
                                            anchors.fill: parent
                                            theme: root.theme
                                            showIcon: false
                                            showValue: false
                                            wheelEnabled: false
                                            thumbAlwaysVisible: true
                                            value: streamDelegate.modelData.audio ? streamDelegate.modelData.audio.volume : 0
                                            maximum: 1.5
                                            accent: root.theme.primary
                                            available: Boolean(streamDelegate.modelData.audio)
                                            onValueRequested: function(value) {
                                                if (streamDelegate.modelData.audio)
                                                    streamDelegate.modelData.audio.volume = value
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "SAÍDAS"
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            Flickable {
                id: outputFlick
                width: parent.width
                height: 76
                contentWidth: width
                contentHeight: outputList.implicitHeight
                clip: true

                WheelKinetic { scrollTarget: outputFlick }

                Column {
                    id: outputList
                    width: parent.width
                    spacing: root.theme.spacingTokens.tight

                    Repeater {
                        model: root.outputs

                        delegate: PopupListRow {
                            id: outputDelegate
                            theme: root.theme
                            required property var modelData
                            rowHeight: 36
                            cornerRadius: root.theme.radiusMd
                            active: modelData === root.sink
                            idleColor: "transparent"
                            idleBorderWidth: 0
                            leadingTablerIcon: active ? "dashboard-check" : "bar-volume"
                            leadingIconColor: modelData === root.sink ? root.theme.primary : root.theme.foreground
                            leadingIconPixelSize: root.theme.iconTokens.md
                            title: root.nodeName(outputDelegate.modelData, "Output")
                            titleColor: active ? root.theme.primary : root.theme.foreground
                            subtitle: active ? "Em uso" : ""
                            subtitleColor: root.theme.primary
                            activeBorderWidth: 1
                            activeBorderColor: root.theme.withAlpha(root.theme.primary, 0.35)

                            interactionHandlers: TapHandler {
                                onTapped: Pipewire.preferredDefaultAudioSink = outputDelegate.modelData
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // INPUT -------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 88
                radius: root.theme.radiusXl
                color: root.theme.adaptiveCardSurface
                border.width: 1
                border.color: root.theme.adaptiveCardBorder

                Column {
                    anchors.fill: parent
                    anchors.margins: root.theme.popupInsets.compactPlus
                    spacing: root.theme.spacingTokens.md

                    Row {
                        width: parent.width
                        height: 34
                        spacing: root.theme.spacingTokens.mdPlus

                        Rectangle {
                            id: micMuteButton
                            width: 32
                            height: 32
                            radius: root.theme.radiusButton
                            color: micMuteHover.hovered
                                   ? root.theme.glassActiveSurface
                                   : root.theme.glassHoverSurface

                            TablerIcon {
                                anchors.centerIn: parent
                                width: root.theme.iconTokens.lgPlus
                                height: root.theme.iconTokens.lgPlus
                                iconName: root.source?.audio?.muted ? "microphone-off" : "microphone"
                                iconColor: root.source?.audio?.muted ? root.theme.red : root.theme.pink
                            }

                            HoverHandler { id: micMuteHover }
                            TapHandler {
                                onTapped: {
                                    if (root.source?.audio)
                                        root.source.audio.muted = !root.source.audio.muted
                                }
                            }
                        }

                        Column {
                            width: parent.width - 41
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.micro

                            Text {
                                text: root.source?.audio?.muted ? "Microfone · mutado" : "Microfone"
                                color: root.source?.audio?.muted ? root.theme.red : root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.meta
                            }

                            Text {
                                width: parent.width
                                text: root.nodeName(root.source, "Nenhuma entrada")
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.subtitle
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: root.theme.spacingTokens.md

                        Item {
                            width: parent.width - 50
                            height: 24

                            SliderRow {
                                anchors.fill: parent
                                theme: root.theme
                                showIcon: false
                                showValue: false
                                wheelEnabled: false
                                thumbAlwaysVisible: true
                                value: root.source?.audio ? root.source.audio.volume : 0
                                maximum: 1.5
                                accent: root.theme.pink
                                available: Boolean(root.source?.audio)
                                onValueRequested: function(value) {
                                    if (root.source?.audio)
                                        root.source.audio.volume = value
                                }
                            }
                        }

                        Text {
                            width: 42
                            text: root.source?.audio
                                  ? Math.round(root.source.audio.volume * 100) + "%"
                                  : "--%"
                            color: root.theme.offWhite
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.body
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Text {
                text: "ENTRADAS"
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            Flickable {
                id: inputFlick
                width: parent.width
                height: 76
                contentWidth: width
                contentHeight: inputList.implicitHeight
                clip: true

                WheelKinetic { scrollTarget: inputFlick }

                Column {
                    id: inputList
                    width: parent.width
                    spacing: root.theme.spacingTokens.tight

                    Repeater {
                        model: root.inputs

                        delegate: PopupListRow {
                            id: inputDelegate
                            theme: root.theme
                            required property var modelData
                            rowHeight: 36
                            cornerRadius: root.theme.radiusMd
                            active: modelData === root.source
                            idleColor: "transparent"
                            idleBorderWidth: 0
                            activeBorderWidth: 1
                            activeBorderColor: root.theme.withAlpha(root.theme.primary, 0.40)
                            leadingTablerIcon: active ? "dashboard-check" : "microphone"
                            leadingIconColor: modelData === root.source ? root.theme.primary : root.theme.foreground
                            leadingIconPixelSize: root.theme.iconTokens.md
                            title: root.nodeName(inputDelegate.modelData, "Entrada")
                            titleColor: active ? root.theme.primary : root.theme.foreground
                            subtitle: active ? "Em uso" : ""
                            subtitleColor: root.theme.primary

                            interactionHandlers: TapHandler {
                                onTapped: Pipewire.preferredDefaultAudioSource = inputDelegate.modelData
                            }
                        }
                    }
                }
            }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
