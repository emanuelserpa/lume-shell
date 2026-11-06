pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "CommandResult.js" as CommandResult

Item {
    id: root
    visible: false
    width: 0
    height: 0
    property bool available: false
    property bool bypassed: false
    property bool busy: false
    property bool popupOpen: false
    property string outputPreset: ""
    property string inputPreset: ""
    property var outputPresets: []
    property var inputPresets: []
    property string error: ""

    function refresh() { statusState.refresh() }
    function applyStatus(result) {
        if (!result) return
        if (!result.ok) {
            root.available = false
            root.error = String(result.error ?? "EasyEffects indisponível.")
            return
        }
        const data = result.data ?? ({})
        root.available = Boolean(data.available)
        root.bypassed = Boolean(data.bypassed)
        root.outputPreset = String(data.output_preset ?? "")
        root.inputPreset = String(data.input_preset ?? "")
        root.outputPresets = Array.isArray(data.output_presets) ? data.output_presets : []
        root.inputPresets = Array.isArray(data.input_presets) ? data.input_presets : []
        root.error = ""
    }
    function runAction(args) {
        if (actionProc.running || root.busy) return
        root.busy = true
        root.error = ""
        actionProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/easyeffects-control.py"].concat(args)
        actionProc.running = true
    }
    function setBypassed(value) { runAction(["bypass", value ? "on" : "off"]) }
    function loadPreset(pipeline, name) { runAction(["preset", pipeline, name]) }
    function openWindow() { runAction(["open"]) }

    Timer {
        id: refreshAfterAction
        interval: 400
        repeat: false
        onTriggered: root.refresh()
    }
    CommandJson {
        id: statusState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/easyeffects-control.py", "status"]
        interval: root.popupOpen ? 15000 : 0
        autoStart: false
        onResultChanged: root.applyStatus(statusState.result)
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                const result = CommandResult.decode(this.text)
                if (!result.ok) root.error = result.error
                refreshAfterAction.restart()
            }
        }
        onRunningChanged: {
            if (!running && root.busy) {
                root.busy = false
                refreshAfterAction.restart()
            }
        }
    }
}
