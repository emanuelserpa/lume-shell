import QtQuick
import Quickshell.Io
import "CommandActionResult.js" as CommandActionResult
import "../services/CommandProcessLifecycle.js" as CommandProcessLifecycle

// One-shot helper command with error plumbing and post-run refresh.
// Sibling of CommandJson (which polls status); use for set/apply actions.
Item {
    id: root
    property list<string> baseCommand: []
    property string fallbackError: "Falha ao executar."
    property string error: ""
    property var result: ({ok: false, version: 1, data: ({}), error: ""})
    property var refreshTarget: null
    property int refreshDelay: 350
    property string _stdout: ""
    property string _stderr: ""
    property bool _completionReported: false
    property var processLifecycle: ({restartPending: false, startObserved: false})
    readonly property bool busy: proc.running
    signal succeeded()
    signal failed()
    signal finished()
    signal started()

    width: 0
    height: 0

    function run(args) {
        if (proc.running)
            return
        root.error = ""
        root._stdout = ""
        root._stderr = ""
        root._completionReported = false
        CommandProcessLifecycle.requestStart(root.processLifecycle)
        proc.command = root.baseCommand.concat(args ?? [])
        startFailureTimer.restart()
        proc.running = true
        root.started()
    }

    function complete(exitCode) {
        if (root._completionReported)
            return
        root._completionReported = true
        const outcome = CommandActionResult.complete(
            exitCode, root._stdout, root._stderr, root.fallbackError)
        root.result = outcome.result
        root.error = outcome.error
        if (outcome.ok)
            root.succeeded()
        else
            root.failed()
    }

    Timer {
        id: refreshTimer
        interval: root.refreshDelay
        repeat: false
        onTriggered: {
            if (root.refreshTarget)
                root.refreshTarget.refresh()
        }
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
            startFailureTimer.stop()
            root.complete(exitCode)
        }
        onRunningChanged: {
            if (!running) {
                root.finished()
                refreshTimer.restart()
            }
        }
    }
}
