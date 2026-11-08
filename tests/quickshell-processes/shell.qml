pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

ShellRoot {
    id: root

    readonly property string freshCommand:
        Quickshell.shellDir + "/fixtures/fresh.sh"
    property bool restartRequested: false
    property double startedAt: Date.now()
    property bool actionSuccessSeen: false
    property bool actionFailureSeen: false

    CommandJson {
        id: success
        autoStart: true
        interval: 0
        command: ["sh", Quickshell.shellDir + "/fixtures/success.sh"]
    }

    CommandJson {
        id: failure
        autoStart: true
        interval: 0
        command: ["sh", Quickshell.shellDir + "/fixtures/nonzero.sh"]
    }

    CommandJson {
        id: empty
        autoStart: true
        interval: 0
        command: ["sh", Quickshell.shellDir + "/fixtures/empty.sh"]
    }

    CommandJson {
        id: pending
        autoStart: false
        interval: 0
        command: root.restartRequested
            ? ["sh", root.freshCommand]
            : ["python3", "-B", Quickshell.shellDir + "/fixtures/pending.py",
               Quickshell.shellDir + "/pending-started"]
    }

    CommandAction {
        id: actionSuccess
        baseCommand: ["sh"]
        onSucceeded: root.actionSuccessSeen = true
    }

    CommandAction {
        id: actionFailure
        baseCommand: ["sh"]
        onFailed: root.actionFailureSeen = actionFailure.error.includes("deliberate failure")
    }

    Component.onCompleted: {
        pending.startQuery()
        actionSuccess.run([Quickshell.shellDir + "/fixtures/success.sh"])
        actionFailure.run([Quickshell.shellDir + "/fixtures/nonzero.sh"])
    }

    Timer {
        interval: 2300
        running: true
        repeat: false
        onTriggered: {
            root.restartRequested = true
            pending.restart()
        }
    }

    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            const successDone = success.generation === 1
                && success.result.ok
                && success.result.data.text === "correct"
            const failureDone = failure.generation === 1
                && !failure.result.ok
                && failure.result.error.includes("deliberate failure")
            const emptyDone = empty.generation === 1
                && !empty.result.ok
                && empty.result.error.length > 0
            const restartDone = root.restartRequested
                && pending.generation === 1
                && pending.result.ok
                && pending.result.data.text === "fresh"
            const actionsDone = root.actionSuccessSeen && root.actionFailureSeen

            if (successDone && failureDone && emptyDone && restartDone && actionsDone) {
                console.log("QUICKSHELL_PROCESS_INTEGRATION_PASS")
                Qt.quit()
            } else if (Date.now() - root.startedAt > 9000) {
                console.error("QUICKSHELL_PROCESS_INTEGRATION_FAIL",
                              JSON.stringify({
                                  success: success.result,
                                  failure: failure.result,
                                  empty: empty.result,
                                  pending: pending.result,
                                  restartRequested: root.restartRequested,
                                  actionSuccessSeen: root.actionSuccessSeen,
                                  actionFailureSeen: root.actionFailureSeen,
                                  actionFailure: actionFailure.error
                              }))
                Qt.exit(1)
            }
        }
    }
}
