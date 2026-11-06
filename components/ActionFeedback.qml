import QtQuick

// Shared action busy/error state and optional timed error dismissal.
Item {
    id: root

    property bool busy: false
    property string busyTarget: ""
    property string errorText: ""
    property string errorTarget: ""
    property bool quiet: false
    property int clearAfter: 7000

    visible: false
    width: 0
    height: 0

    function begin(target, quietAction) {
        root.quiet = Boolean(quietAction)
        if (root.quiet)
            return
        root.clearError()
        root.busyTarget = String(target ?? "")
        root.busy = true
    }

    function finish() {
        root.busy = false
        root.busyTarget = ""
    }

    function succeed() {
        if (!root.quiet)
            root.clearError()
    }

    function fail(message, target) {
        if (root.quiet)
            return
        root.errorText = String(message ?? "A operação falhou.")
        root.errorTarget = target === undefined
                          ? root.busyTarget
                          : String(target ?? "")
        if (root.clearAfter > 0)
            clearTimer.restart()
    }

    function clearError() {
        clearTimer.stop()
        root.errorText = ""
        root.errorTarget = ""
    }

    Timer {
        id: clearTimer
        interval: root.clearAfter
        repeat: false
        onTriggered: root.clearError()
    }
}
