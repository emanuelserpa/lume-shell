import QtQuick
import Quickshell
import Quickshell.Io
import "ProcessLifecycle.js" as ProcessLifecycle

// Supervises the native clipboard daemon: relaunches it with backoff if
// it ever exits unexpectedly. The daemon itself only restarts its
// `wl-paste --watch` child; it cannot recreate itself, so without this
// policy a dead daemon silently disables clipboard history.
Item {
    id: root
    width: 0
    height: 0
    visible: false

    // Set while tearing down so the final exit is not relaunched.
    property bool disarmed: false
    property int failures: 0
    property double lastStartMs: 0

    function backoffMs() {
        if (root.failures <= 1) return 1000
        if (root.failures === 2) return 2000
        if (root.failures === 3) return 5000
        return 15000
    }

    Process {
        id: daemonProc
        property bool observedStart: false
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/clipboard-daemon.py"
        ]
        running: true

        onRunningChanged: {
            if (running) {
                ProcessLifecycle.consumeStartedStop(daemonProc)
                root.lastStartMs = Date.now()
                return
            }
            if (!ProcessLifecycle.consumeStartedStop(daemonProc))
                return
            if (root.disarmed)
                return
            // A long-lived run resets the streak: only rapid deaths back off.
            if (Date.now() - root.lastStartMs > 60000)
                root.failures = 0
            root.failures += 1
            restartTimer.interval = root.backoffMs()
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: {
            if (root.disarmed || daemonProc.running)
                return
            daemonProc.running = true
        }
    }

    Component.onDestruction: {
        root.disarmed = true
        restartTimer.stop()
    }
}
