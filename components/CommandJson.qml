import QtQuick
import Quickshell.Io
import "CommandActionResult.js" as CommandActionResult
import "../services/CommandProcessLifecycle.js" as CommandProcessLifecycle

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
    property var processLifecycle: ({restartPending: false, startObserved: false})
    property string _stdout: ""
    property string _stderr: ""
    property bool _completionReported: false
    width: 0
    height: 0

    function refresh() {
        if (!proc.running && !root.processLifecycle.restartPending)
            root.startQuery()
    }

    function startQuery() {
        if (proc.running || root.processLifecycle.restartPending)
            return
        CommandProcessLifecycle.requestStart(root.processLifecycle)
        root._stdout = ""
        root._stderr = ""
        root._completionReported = false
        startFailureTimer.restart()
        proc.running = true
    }

    // Restartable query: drop an in-flight run and start over with the
    // current command. Used by debounced search-as-you-type.
    function restart() {
        if (root.processLifecycle.restartPending)
            return
        if (proc.running) {
            CommandProcessLifecycle.requestRestart(root.processLifecycle, true)
            startFailureTimer.stop()
            proc.running = false
        } else {
            root.startQuery()
        }
    }

    function complete(exitCode) {
        if (root._completionReported)
            return
        root._completionReported = true
        startFailureTimer.stop()
        if (CommandProcessLifecycle.consumeRestart(root.processLifecycle)) {
            root.startQuery()
            return
        }
        const outcome = CommandActionResult.complete(
            exitCode, root._stdout, root._stderr, "Falha ao consultar.")
        const normalized = outcome.result
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

    Timer {
        id: startFailureTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (CommandProcessLifecycle.shouldReportStartFailure(
                    root.processLifecycle, proc.running)) {
                root._stderr = "O processo auxiliar não iniciou."
                root.complete(127)
            }
        }
    }

    Process {
        id: proc
        command: root.command
        onStarted: {
            CommandProcessLifecycle.observeStart(root.processLifecycle)
            startFailureTimer.stop()
        }
        stdout: StdioCollector {
            onStreamFinished: root._stdout = this.text
        }
        stderr: StdioCollector {
            onStreamFinished: root._stderr = this.text
        }
        onExited: function(exitCode, exitStatus) {
            root.complete(exitCode)
        }
    }
}
