import QtQuick
import Quickshell.Io
import "../services/CommandResult.js" as CommandResult

Item {
    id: root
    property list<string> command: []
    property int interval: 600000
    property bool autoStart: true
    property string text: ""
    property string tooltip: ""
    property string cssClass: ""
    property var payload: ({})
    property var result: ({ok: false, version: 1, data: ({}), error: "Aguardando resposta."})
    property int generation: 0
    width: 0
    height: 0

    function refresh() {
        if (!proc.running)
            proc.running = true
    }

    // Restartable query: drop an in-flight run and start over with the
    // current command. Used by debounced search-as-you-type.
    function restart() {
        if (proc.running)
            proc.running = false
        proc.running = true
    }

    Component.onCompleted: {
        if (root.autoStart)
            refresh()
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.autoStart && root.interval > 0
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                const normalized = CommandResult.decode(this.text)
                const obj = normalized.data
                root.result = normalized
                root.payload = obj
                root.generation++
                root.text = obj.text ?? ""
                root.tooltip = normalized.ok
                               ? (obj.tooltip ?? "")
                               : normalized.error
                root.cssClass = Array.isArray(obj.class) ? obj.class.join(" ") : (obj.class ?? "")
            }
        }
    }
}
