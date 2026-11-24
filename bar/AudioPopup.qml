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
    property bool settingsAvailable: true

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

    implicitWidth: root.theme.popupWidths.large
    implicitHeight: Math.min(820, maxAllowedHeight,
                             audioContentList.contentHeight + root.theme.popupInsets.large * 2)
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

    function rawNodeLabel(node) {
        if (!node) return ""
        return String(node.description || node.nickname || node.name || "").trim()
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

        return rawNodeLabel(node) || fallback
    }

    function nodeDetail(node, primaryTitle) {
        const raw = rawNodeLabel(node)
        if (!raw || raw.toLowerCase() === String(primaryTitle || "").trim().toLowerCase())
            return ""
        return raw
    }

    function streamName(node) {
        if (!node) return "Aplicativo"
        const p = (node.ready && node.properties) ? node.properties : (node.properties || {})
        const app = p["application.name"] || node.description || p["node.name"] || node.name || p["media.name"]
        if (app && String(app).length > 0) return String(app)
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

    function outputIconName(node) {
        if (!node?.audio || node.audio.muted) return "bar-volume-off"
        if (node.audio.volume <= 0) return "bar-volume-zero"
        if (node.audio.volume < 0.5) return "bar-volume-low"
        return "bar-volume"
    }

    function isNodeMuted(node) {
        return Boolean(node?.audio?.muted)
    }

    function isNodeBoosted(node) {
        return Boolean(node?.audio && !node.audio.muted && node.audio.volume > 1.001)
    }

    function volumeText(node) {
        return node?.audio ? Math.round(node.audio.volume * 100) + "%" : "--%"
    }

    component AudioEndpointCard: Rectangle {
        id: endpointCard
        required property var cardTheme
        required property var endpointNode
        required property string roleTitle
        required property string emptyTitle
        required property string primaryIcon
        required property string mutedIcon
        required property color accentColor
        required property string deviceTitle
        property string deviceDetail: ""

        readonly property bool available: Boolean(endpointNode?.audio)
        readonly property bool muted: Boolean(endpointNode?.audio?.muted)
        readonly property bool boosted: Boolean(endpointNode?.audio && !muted && endpointNode.audio.volume > 1.001)
        readonly property real volumeValue: endpointNode?.audio ? endpointNode.audio.volume : 0
        readonly property string percentLabel: endpointNode?.audio ? Math.round(endpointNode.audio.volume * 100) + "%" : "--%"

        width: parent ? parent.width : 0
        implicitHeight: endpointColumn.implicitHeight + cardTheme.popupInsets.standard * 2
        radius: cardTheme.radiusXl
        color: cardTheme.adaptiveCardSurface
        border.width: 1
        border.color: muted
            ? cardTheme.withAlpha(cardTheme.red, 0.42)
            : (boosted ? cardTheme.withAlpha(cardTheme.yellow, 0.42) : cardTheme.adaptiveCardBorder)

        Column {
            id: endpointColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: endpointCard.cardTheme.popupInsets.standard
            spacing: endpointCard.cardTheme.spacingTokens.md

            Row {
                width: parent.width
                spacing: endpointCard.cardTheme.spacingTokens.mdPlus

                Rectangle {
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    radius: endpointCard.cardTheme.radiusButton
                    color: endpointCard.muted
                        ? endpointCard.cardTheme.withAlpha(endpointCard.cardTheme.red, muteHover.hovered ? 0.24 : 0.14)
                        : (muteHover.hovered
                            ? endpointCard.cardTheme.glassActiveSurface
                            : endpointCard.cardTheme.glassHoverSurface)

                    TablerIcon {
                        anchors.centerIn: parent
                        width: endpointCard.cardTheme.iconTokens.lgPlus
                        height: endpointCard.cardTheme.iconTokens.lgPlus
                        iconName: endpointCard.muted ? endpointCard.mutedIcon : endpointCard.primaryIcon
                        iconColor: endpointCard.muted
                            ? endpointCard.cardTheme.red
                            : (endpointCard.boosted ? endpointCard.cardTheme.yellow : endpointCard.accentColor)
                    }

                    HoverHandler { id: muteHover }
                    TapHandler {
                        enabled: endpointCard.available
                        onTapped: {
                            if (endpointCard.endpointNode?.audio)
                                endpointCard.endpointNode.audio.muted = !endpointCard.endpointNode.audio.muted
                        }
                    }
                }

                Column {
                    width: Math.max(0, parent.width - 32 - endpointCard.cardTheme.spacingTokens.mdPlus)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: endpointCard.cardTheme.spacingTokens.micro

                    Text {
                        width: parent.width
                        text: endpointCard.muted
                            ? endpointCard.roleTitle + " · mutado"
                            : (endpointCard.boosted ? endpointCard.roleTitle + " · amplificado" : endpointCard.roleTitle)
                        color: endpointCard.muted
                            ? endpointCard.cardTheme.red
                            : (endpointCard.boosted ? endpointCard.cardTheme.yellow : endpointCard.cardTheme.surfaceVariantForeground)
                        font.family: endpointCard.cardTheme.fontFamily
                        font.pixelSize: endpointCard.cardTheme.typeTokens.meta
                        font.weight: (endpointCard.muted || endpointCard.boosted) ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: endpointCard.available ? endpointCard.deviceTitle : endpointCard.emptyTitle
                        color: endpointCard.cardTheme.surfaceForeground
                        font.family: endpointCard.cardTheme.fontFamily
                        font.pixelSize: endpointCard.cardTheme.typeTokens.subtitle
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: endpointCard.available && endpointCard.deviceDetail.length > 0
                        width: parent.width
                        text: endpointCard.deviceDetail
                        color: endpointCard.cardTheme.surfaceVariantForeground
                        font.family: endpointCard.cardTheme.fontFamily
                        font.pixelSize: endpointCard.cardTheme.typeTokens.meta
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                width: parent.width
                spacing: endpointCard.cardTheme.spacingTokens.sm

                Item {
                    width: Math.max(0, parent.width - 52 - endpointCard.cardTheme.spacingTokens.sm)
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    SliderRow {
                        anchors.fill: parent
                        theme: endpointCard.cardTheme
                        showIcon: false
                        showValue: false
                        wheelEnabled: true
                        thumbAlwaysVisible: true
                        value: endpointCard.volumeValue
                        maximum: 1.5
                        dragMaximum: 1.0
                        referenceValue: 1.0
                        accent: endpointCard.muted ? endpointCard.cardTheme.red : endpointCard.accentColor
                        boostAccent: endpointCard.muted ? endpointCard.cardTheme.red : endpointCard.cardTheme.yellow
                        available: endpointCard.available
                        onValueRequested: function(nextValue) {
                            if (endpointCard.endpointNode?.audio)
                                endpointCard.endpointNode.audio.volume = nextValue
                        }
                    }
                }

                Rectangle {
                    width: 52
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: endpointCard.cardTheme.radiusSm
                    color: endpointCard.boosted
                        ? endpointCard.cardTheme.withAlpha(endpointCard.cardTheme.yellow, resetHover.containsMouse ? 0.28 : 0.16)
                        : "transparent"
                    border.width: endpointCard.boosted ? 1 : 0
                    border.color: endpointCard.boosted
                        ? endpointCard.cardTheme.withAlpha(endpointCard.cardTheme.yellow, 0.45)
                        : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: endpointCard.percentLabel
                        color: endpointCard.muted
                            ? endpointCard.cardTheme.red
                            : (endpointCard.boosted ? endpointCard.cardTheme.yellow : endpointCard.cardTheme.surfaceForeground)
                        font.family: endpointCard.cardTheme.fontFamily
                        font.pixelSize: endpointCard.cardTheme.typeTokens.body
                        font.weight: endpointCard.boosted ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        id: resetHover
                        anchors.fill: parent
                        enabled: endpointCard.boosted
                        hoverEnabled: endpointCard.boosted
                        cursorShape: endpointCard.boosted ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (endpointCard.endpointNode?.audio)
                                endpointCard.endpointNode.audio.volume = 1.0
                        }
                    }
                }
            }
        }
    }

    component AudioDeviceSelector: Column {
        id: selector
        required property var selectorTheme
        required property string sectionTitle
        required property var devices
        required property var activeDevice
        required property string defaultTitle
        required property string itemIcon
        required property color activeAccent
        required property var nameFn
        required property var detailFn
        signal deviceSelected(var node)

        width: parent ? parent.width : 0
        spacing: selectorTheme.spacingTokens.xs
        visible: Array.isArray(devices) && devices.length > 0

        Text {
            text: selector.sectionTitle + " · " + selector.devices.length
            color: selector.selectorTheme.surfaceVariantForeground
            font.family: selector.selectorTheme.fontFamily
            font.pixelSize: selector.selectorTheme.typeTokens.meta
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }

        Column {
            width: parent.width
            spacing: selector.selectorTheme.spacingTokens.tight

            Repeater {
                model: selector.devices

                delegate: PopupListRow {
                    id: deviceDelegate
                    required property var modelData

                    readonly property string titleLabel: selector.nameFn(modelData, selector.defaultTitle)
                    readonly property string detailLabel: selector.detailFn(modelData, titleLabel)

                    theme: selector.selectorTheme
                    rowHeight: 38
                    cornerRadius: selector.selectorTheme.radiusMd
                    active: modelData === selector.activeDevice
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    activeBorderWidth: 1
                    activeBorderColor: selector.selectorTheme.withAlpha(selector.activeAccent, 0.38)
                    leadingTablerIcon: active ? "dashboard-check" : selector.itemIcon
                    leadingIconColor: active ? selector.activeAccent : selector.selectorTheme.surfaceForeground
                    leadingIconPixelSize: selector.selectorTheme.iconTokens.md
                    title: titleLabel
                    titleColor: active ? selector.activeAccent : selector.selectorTheme.surfaceForeground
                    subtitle: active
                        ? (detailLabel.length > 0 ? "Em uso · " + detailLabel : "Em uso")
                        : detailLabel
                    subtitleColor: active ? selector.activeAccent : selector.selectorTheme.surfaceVariantForeground

            interactionHandlers: TapHandler {
                        onTapped: selector.deviceSelected(deviceDelegate.modelData)
                    }
                }
            }
        }
    }

    component EffectsPresetRow: PopupListRow {
        id: presetRow
        required property var rowTheme
        required property string pipelineName
        required property string pipelineLabel
        required property string leadingIcon
        required property color iconAccent
        required property string activePreset
        required property string emptyPresetText
        required property var presetList
        signal cycleRequested(string pipeline, int direction)

        theme: rowTheme
        width: parent ? parent.width : 0
        rowHeight: 38
        leadingTablerIcon: leadingIcon
        title: activePreset || emptyPresetText
        subtitle: pipelineLabel + " · " + presetList.length + " presets"
        titleColor: rowTheme.surfaceForeground
        leadingIconColor: iconAccent
        idleColor: "transparent"
        idleBorderWidth: 0
        trailing: Component {
            Row {
                spacing: presetRow.rowTheme.spacingTokens.xs
                PopupIconButton {
                    theme: presetRow.rowTheme
                    width: 24
                    height: 24
                    tablerIcon: "dashboard-chevron-left"
                    iconPixelSize: presetRow.rowTheme.iconTokens.smPlus
                    enabled: EasyEffectsState.available && !EasyEffectsState.busy && presetRow.presetList.length > 1
                    onClicked: presetRow.cycleRequested(presetRow.pipelineName, -1)
                }
                PopupIconButton {
                    theme: presetRow.rowTheme
                    width: 24
                    height: 24
                    tablerIcon: "dashboard-chevron-right"
                    iconPixelSize: presetRow.rowTheme.iconTokens.smPlus
                    enabled: EasyEffectsState.available && !EasyEffectsState.busy && presetRow.presetList.length > 1
                    onClicked: presetRow.cycleRequested(presetRow.pipelineName, 1)
                }
            }
        }
        interactionHandlers: TapHandler {
            onTapped: EasyEffectsState.openWindow()
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Keys.onEscapePressed: root.visible = false

        ScrollableList {
            id: audioContentList
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.large
            theme: root.theme
            contentSpacing: root.theme.spacingTokens.md
            showScrollBar: true
            reserveScrollBarSpace: false
            scrollBarThumbColor: root.theme.primary

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 32
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
                subtitle: root.isNodeMuted(root.sink)
                    ? "Saída mutada"
                    : (root.isNodeBoosted(root.sink) ? "Amplificação > 100%" : root.volumeText(root.sink))
                subtitleColor: root.isNodeMuted(root.sink)
                    ? root.theme.red
                    : (root.isNodeBoosted(root.sink) ? root.theme.yellow : root.theme.surfaceVariantForeground)

                PopupSettingsButton {
                    visible: root.settingsAvailable
                    width: 26
                    height: 24
                    theme: root.theme
                    onClicked: root.settingsRequested()
                }

                Rectangle {
                    height: 20
                    width: pipewireLabel.implicitWidth + root.theme.spacingTokens.md
                    radius: root.theme.radiusSm
                    color: root.theme.glassCardSurface
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.border, 0.40)

                    Text {
                        id: pipewireLabel
                        anchors.centerIn: parent
                        text: "PipeWire"
                        color: root.theme.surfaceVariantForeground
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

            // 1. OUTPUT ---------------------------------------------------
            AudioEndpointCard {
                readonly property string sinkTitle: root.nodeName(root.sink, "Nenhuma saída")
                cardTheme: root.theme
                endpointNode: root.sink
                roleTitle: "Saída"
                emptyTitle: "Nenhuma saída"
                primaryIcon: root.outputIconName(root.sink)
                mutedIcon: "bar-volume-off"
                accentColor: root.theme.primary
                deviceTitle: sinkTitle
                deviceDetail: root.nodeDetail(root.sink, sinkTitle)
            }

            AudioDeviceSelector {
                selectorTheme: root.theme
                sectionTitle: "SAÍDAS"
                devices: root.outputs
                activeDevice: root.sink
                defaultTitle: "Saída"
                itemIcon: "bar-volume"
                activeAccent: root.theme.primary
                nameFn: root.nodeName
                detailFn: root.nodeDetail
                onDeviceSelected: function(node) {
                    Pipewire.preferredDefaultAudioSink = node
                }
            }

            // 2. APLICATIVOS (Per-App Streams) ----------------------------
            Column {
                visible: root.streams.length > 0
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                Text {
                    text: "APLICATIVOS · " + root.streams.length
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }

                Column {
                    width: parent.width
                    spacing: root.theme.spacingTokens.xs

                    Repeater {
                        model: root.streams

                        delegate: PopupListRow {
                            id: streamDelegate
                            required property var modelData

                            readonly property bool streamMuted: root.isNodeMuted(modelData)
                            readonly property bool streamBoosted: root.isNodeBoosted(modelData)
                            readonly property string detailText: root.streamDetail(modelData)

                            theme: root.theme
                            rowHeight: detailText.length > 0 ? 66 : 54
                            active: false
                            activeBorderWidth: streamMuted || streamBoosted ? 1 : 0
                            idleBorderWidth: streamMuted || streamBoosted ? 1 : 1
                            idleBorderColor: streamMuted
                                ? root.theme.withAlpha(root.theme.red, 0.34)
                                : (streamBoosted ? root.theme.withAlpha(root.theme.yellow, 0.36) : root.theme.adaptiveCardBorder)

                            Column {
                                anchors.fill: parent
                                anchors.margins: root.theme.popupInsets.smallPlus
                                spacing: streamDelegate.detailText.length > 0 ? 2 : 4

                                Row {
                                    width: parent.width
                                    height: 18
                                    spacing: root.theme.spacingTokens.sm

                                    Text {
                                        text: root.streamIcon(streamDelegate.modelData)
                                        color: streamDelegate.streamMuted ? root.theme.red : root.theme.primary
                                        font.family: root.theme.nerdFontFamily
                                        font.pixelSize: root.theme.iconTokens.md
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        width: Math.max(0, parent.width - 102)
                                        text: root.streamName(streamDelegate.modelData)
                                        color: streamDelegate.streamMuted ? root.theme.surfaceVariantForeground : root.theme.surfaceForeground
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.body
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: root.theme.radiusSm
                                        color: streamDelegate.streamMuted
                                            ? root.theme.withAlpha(root.theme.red, 0.22)
                                            : (streamMuteHover.hovered ? root.theme.glassHoverSurface : "transparent")
                                        anchors.verticalCenter: parent.verticalCenter

                                        TablerIcon {
                                            anchors.centerIn: parent
                                            width: root.theme.iconTokens.sm
                                            height: root.theme.iconTokens.sm
                                            iconName: streamDelegate.streamMuted ? "bar-volume-off" : "bar-volume"
                                            iconColor: streamDelegate.streamMuted ? root.theme.red : root.theme.surfaceForeground
                                        }

                                        HoverHandler { id: streamMuteHover }
                                        TapHandler {
                                            onTapped: {
                                                if (streamDelegate.modelData.audio)
                                                    streamDelegate.modelData.audio.muted = !streamDelegate.modelData.audio.muted
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 46
                                        height: 18
                                        radius: root.theme.radiusSm
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: streamDelegate.streamBoosted
                                            ? root.theme.withAlpha(root.theme.yellow, streamResetHover.containsMouse ? 0.28 : 0.16)
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.volumeText(streamDelegate.modelData)
                                            color: streamDelegate.streamMuted
                                                ? root.theme.red
                                                : (streamDelegate.streamBoosted ? root.theme.yellow : root.theme.surfaceForeground)
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.meta
                                            font.weight: streamDelegate.streamBoosted ? Font.DemiBold : Font.Medium
                                        }

                                        MouseArea {
                                            id: streamResetHover
                                            anchors.fill: parent
                                            enabled: streamDelegate.streamBoosted
                                            hoverEnabled: streamDelegate.streamBoosted
                                            cursorShape: streamDelegate.streamBoosted ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (streamDelegate.modelData.audio)
                                                    streamDelegate.modelData.audio.volume = 1.0
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: streamDelegate.detailText.length > 0
                                    width: parent.width
                                    text: streamDelegate.detailText
                                    color: root.theme.surfaceVariantForeground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.meta
                                    elide: Text.ElideRight
                                }

                                Item {
                                    width: parent.width
                                    height: 24
                                    opacity: streamDelegate.streamMuted ? 0.65 : 1.0

                                    SliderRow {
                                        anchors.fill: parent
                                        theme: root.theme
                                        showIcon: false
                                        showValue: false
                                        wheelEnabled: true
                                        thumbAlwaysVisible: true
                                        value: streamDelegate.modelData.audio ? streamDelegate.modelData.audio.volume : 0
                                        maximum: 1.5
                                        dragMaximum: 1.0
                                        referenceValue: 1.0
                                        accent: streamDelegate.streamMuted ? root.theme.red : root.theme.primary
                                        boostAccent: streamDelegate.streamMuted ? root.theme.red : root.theme.yellow
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

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // 3. INPUT ----------------------------------------------------
            AudioEndpointCard {
                readonly property string sourceTitle: root.nodeName(root.source, "Nenhuma entrada")
                cardTheme: root.theme
                endpointNode: root.source
                roleTitle: "Microfone"
                emptyTitle: "Nenhuma entrada"
                primaryIcon: "microphone"
                mutedIcon: "microphone-off"
                accentColor: root.theme.pink
                deviceTitle: sourceTitle
                deviceDetail: root.nodeDetail(root.source, sourceTitle)
            }

            AudioDeviceSelector {
                selectorTheme: root.theme
                sectionTitle: "ENTRADAS"
                devices: root.inputs
                activeDevice: root.source
                defaultTitle: "Entrada"
                itemIcon: "microphone"
                activeAccent: root.theme.pink
                nameFn: root.nodeName
                detailFn: root.nodeDetail
                onDeviceSelected: function(node) {
                    Pipewire.preferredDefaultAudioSource = node
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // 4. EASYEFFECTS ----------------------------------------------
            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                Row {
                    visible: EasyEffectsState.available
                    width: parent.width
                    height: 32
                    spacing: root.theme.spacingTokens.sm

                    Text {
                        width: Math.max(0, parent.width - 58)
                        anchors.verticalCenter: parent.verticalCenter
                        text: EasyEffectsState.bypassed ? "EasyEffects · desativado" : "EasyEffects · ativo"
                        color: root.theme.surfaceForeground
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
                    visible: !EasyEffectsState.available
                    theme: root.theme
                    width: parent.width
                    rowHeight: 38
                    leadingTablerIcon: "bar-controls"
                    leadingIconColor: root.theme.surfaceVariantForeground
                    leadingIconPixelSize: root.theme.iconTokens.md
                    title: "EasyEffects indisponível"
                    titleColor: root.theme.surfaceVariantForeground
                    subtitle: "Toque para abrir o aplicativo"
                    subtitleColor: root.theme.surfaceVariantForeground
                    idleColor: "transparent"
                    idleBorderWidth: 0
                    trailing: Component {
                        TablerIcon {
                            width: root.theme.iconTokens.md
                            height: root.theme.iconTokens.md
                            iconName: "dashboard-chevron-right"
                            iconColor: root.theme.surfaceVariantForeground
                        }
                    }
                    interactionHandlers: TapHandler {
                        onTapped: EasyEffectsState.openWindow()
                    }
                }

                EffectsPresetRow {
                    id: outputPresetRow
                    visible: EasyEffectsState.available
                    rowTheme: root.theme
                    pipelineName: "output"
                    pipelineLabel: "Saída"
                    leadingIcon: "bar-volume"
                    iconAccent: root.theme.primary
                    activePreset: EasyEffectsState.outputPreset
                    emptyPresetText: "Nenhum preset"
                    presetList: EasyEffectsState.outputPresets
                    onCycleRequested: function(pipeline, direction) {
                        root.cycleEffectsPreset(pipeline, direction)
                    }
                }

                EffectsPresetRow {
                    visible: EasyEffectsState.available
                    rowTheme: root.theme
                    pipelineName: "input"
                    pipelineLabel: "Entrada"
                    leadingIcon: "microphone"
                    iconAccent: root.theme.pink
                    activePreset: EasyEffectsState.inputPreset
                    emptyPresetText: "Padrão do microfone"
                    presetList: EasyEffectsState.inputPresets
                    onCycleRequested: function(pipeline, direction) {
                        root.cycleEffectsPreset(pipeline, direction)
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
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
