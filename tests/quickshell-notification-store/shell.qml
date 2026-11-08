import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    readonly property string mode: Quickshell.env("LUME_STORE_TEST_MODE") ?? "failure"
    readonly property int requestInterval: root.mode === "overflow" ? 1 : 100
    readonly property int duration: root.mode === "overflow" ? 3000 : 4000
    property double startedAt: Date.now()
    property int sentRequests: 0

    Timer {
        interval: root.requestInterval
        running: true
        repeat: true
        onTriggered: {
            if (Date.now() - root.startedAt < root.duration) {
                NotificationState.sendStoreRequest({
                    "op": "append",
                    "notification": {
                        "appName": "Controlled test",
                        "summary": "Notification " + root.sentRequests,
                        "body": "Simulated during store outage"
                    }
                })
                root.sentRequests++
                return
            }

            console.log("NOTIFICATION_STORE_SIMULATION_RESULT",
                        JSON.stringify({
                            mode: root.mode,
                            requests: root.sentRequests,
                            pending: NotificationState.pendingStoreRequests.length,
                            started: NotificationState.notificationStoreStarted,
                            failures: NotificationState.notificationStoreFailureCount,
                            warning: NotificationState.notificationStoreWarning,
                            dropped: NotificationState.notificationStoreDroppedRequests
                        }))
            Qt.quit()
        }
    }
}
