import QtQuick
import Quickshell.Io
import "../services/CommandResult.js" as CommandResult

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
        proc.command = root.baseCommand.concat(args ?? [])
        proc.running = true
        root.started()
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

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                root.result = response
                root.error = response.ok ? "" : String(response.error ?? root.fallbackError)
                if (response.ok)
                    root.succeeded()
                else
                    root.failed()
            }
        }
        onRunningChanged: {
            if (!running) {
                root.finished()
                refreshTimer.restart()
            }
        }
    }
}
