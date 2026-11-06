import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.components

Item {
    id: root
    required property var theme
    property bool plain: false

    // PipeWire can add/remove several nodes in one event-loop turn when an
    // audio route changes. Defer rebuilding QML Repeater models until that
    // update has settled, so delegates are not regenerated while PwNodes are
    // being unbound.
    property var nodeValues: Pipewire.nodes.values
    property var outputs: []
    property var inputs: []
    property var streams: []

    implicitWidth: volumePill.implicitWidth
    implicitHeight: root.theme ? root.theme.pillHeight : 25
    property Item popupTarget: null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function openPopup() {
        audioPopup.visible = true
    }

    function haystack(node) {
        return (
            String(node?.name ?? "") + " " +
            String(node?.description ?? "") + " " +
            String(node?.nickname ?? "")
        ).toLowerCase()
    }

    function isVirtualOutput(node) {
        const s = haystack(node)
        return s.includes("easy effects")
            || s.includes("easyeffects")
            || s.includes("auto_null")
            || s.includes("null sink")
            || s.includes("null-sink")
            || s.includes("combined")
            || s.includes("combine sink")
            || s.includes("virtual sink")
            || s.includes("virtual-sink")
            || s.includes("loopback")
    }

    function isVirtualInput(node) {
        const s = haystack(node)
        return s.includes("monitor")
            || s.includes("easy effects")
            || s.includes("easyeffects")
            || s.includes("loopback")
            || s.includes("virtual")
    }

    function activeFirst(nodes, activeNode) {
        const result = []
        if (activeNode && nodes.includes(activeNode)) result.push(activeNode)
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i] !== activeNode) result.push(nodes[i])
        }
        return result
    }

    function availableOutputs(nodes) {
        const result = []
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            if (!node || !node.audio || !node.isSink || node.isStream) continue
            if (isVirtualOutput(node)) continue
            result.push(node)
        }
        return result
    }

    function availableInputs(nodes) {
        const result = []
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            if (!node || !node.audio || node.isSink || node.isStream) continue
            if (isVirtualInput(node)) continue
            result.push(node)
        }
        return result
    }

    function availableStreams(nodes) {
        const result = []
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            if (!node || !node.audio || !node.isStream) continue
            const mediaClass = String(node.type || "")
            if (!node.isSink && !mediaClass.includes("Output") && !mediaClass.includes("Stream/Output/Audio"))
                continue
            const name = String(node.name || "")
            if (name.includes("quickshell") || name.includes("speaker_tuning"))
                continue
            result.push(node)
        }
        return result
    }

    function refreshModels() {
        const nodes = root.nodeValues || []
        root.outputs = activeFirst(availableOutputs(nodes), root.sink)
        root.inputs = activeFirst(availableInputs(nodes), root.source)
        root.streams = availableStreams(nodes)
    }

    onNodeValuesChanged: modelRefresh.restart()
    onSinkChanged: modelRefresh.restart()
    onSourceChanged: modelRefresh.restart()

    Timer {
        id: modelRefresh
        interval: 0
        repeat: false
        onTriggered: root.refreshModels()
    }

    Component.onCompleted: modelRefresh.start()

    readonly property var trackedNodes: outputs.concat(inputs).concat(streams)

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    Pill {
        id: volumePill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: ""
        tablerIcon: !root.sink?.audio || root.sink.audio.muted ? "bar-volume-off"
                    : root.sink.audio.volume <= 0 ? "bar-volume-zero"
                    : root.sink.audio.volume < 0.5 ? "bar-volume-low" : "bar-volume"
        iconSize: root.theme.barIconSize
        fontPixelSize: root.theme.iconTokens.xl
        textColor: root.sink?.audio?.muted ? root.theme.red : root.theme.surfaceForeground
        tooltipText: {
            if (!root.sink?.audio) return "Saída de áudio indisponível"
            const name = root.sink.description || root.sink.nickname || root.sink.name || "Saída de áudio"
            const volume = Math.round(root.sink.audio.volume * 100)
            return root.sink.audio.muted
                ? name + " · Mutado"
                : name + " · " + volume + "%"
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                audioPopup.visible = !audioPopup.visible
            } else if (mouse.button === Qt.RightButton && root.sink?.audio) {
                root.sink.audio.muted = !root.sink.audio.muted
            }
        }

        mouseArea.onWheel: function(wheel) {
            wheel.accepted = true
            if (!root.sink?.audio || root.sink.audio.muted) return
            const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
            root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + delta))
        }
    }

    AudioPopup {
        id: audioPopup
        theme: root.theme
        target: root.popupTarget ? root.popupTarget : volumePill
        sink: root.sink
        source: root.source
        outputs: root.outputs
        inputs: root.inputs
        streams: root.streams

        onSettingsRequested: Quickshell.execDetached(["pwvucontrol"])
    }
}
