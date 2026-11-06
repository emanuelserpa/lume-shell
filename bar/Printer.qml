import QtQuick
import Quickshell
import qs.components

Item {
    id: root

    required property var theme
    property bool plain: false

    property var lastKnownPrinterData: ({})
    readonly property var printerData: {
        const current = printerState.result.data
        if (printerState.result.ok && current.visible)
            return current
        if (printerGrace.running && lastKnownPrinterData.visible) {
            return Object.assign({}, lastKnownPrinterData, {
                status: "error",
                tooltip: "Impressora temporariamente indisponível"
            })
        }
        return current
    }
    readonly property bool detected: Boolean(printerData.visible)
    readonly property int jobCount: Number(printerData.job_count ?? 0)
    readonly property string status: String(printerData.status ?? "ready")

    implicitWidth: detected ? pill.implicitWidth : 0
    implicitHeight: root.theme ? root.theme.pillHeight : 25
    visible: detected

    property alias activeError: actionFeedback.errorText
    property alias actionBusy: actionFeedback.busy

    ActionFeedback {
        id: actionFeedback
        clearAfter: 0
    }

    CommandJson {
        id: printerState
        command: ["python3", Quickshell.shellDir + "/scripts/printer-status.py"]
        interval: root.jobCount > 0 ? 2000
                  : (root.detected ? 5000 : 10000)
        onResultChanged: {
            if (printerState.result.ok && printerState.result.data.visible) {
                root.lastKnownPrinterData = printerState.result.data
                printerGrace.stop()
            } else if (root.lastKnownPrinterData.visible && !printerGrace.running) {
                printerGrace.start()
            }
        }
    }

    Timer {
        id: printerGrace
        interval: 30000
        onTriggered: root.lastKnownPrinterData = ({})
    }

    function refresh() {
        printerState.refresh()
    }

    function openCupsQueue() {
        const printers = root.printerData?.printers ?? []
        const defaultName = String(root.printerData?.default ?? "")
        const defaultPrinter = printers.find(p => p.name === defaultName)
        const printerName = defaultPrinter?.name
            ?? printers[0]?.name
            ?? defaultName
        if (printerName.length === 0)
            return

        const queueUrl = "http://localhost:631/printers/"
            + encodeURIComponent(printerName)
        Quickshell.execDetached([
            "sh", "-c",
            "if command -v system-config-printer >/dev/null 2>&1; then "
            + "exec system-config-printer --show-jobs \"$1\"; "
            + "else exec xdg-open \"$2\"; fi",
            "printer-queue", printerName, queueUrl
        ])
    }

    CommandAction {
        id: actionProc
        baseCommand: [
            "python3",
            Quickshell.shellDir + "/scripts/printer-action.py"
        ]
        fallbackError: "Falha na operação."
        refreshTarget: printerState
        refreshDelay: 450
        onStarted: actionFeedback.busy = true
        onSucceeded: actionFeedback.succeed()
        onFailed: actionFeedback.fail(actionProc.error)
        onFinished: actionFeedback.finish()
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain

        text: root.jobCount > 0 ? String(root.jobCount) : ""
        tablerIcon: "bar-printer"
        iconSize: root.theme.barIconSize
        fontFamily: root.theme.fontFamily
        fontPixelSize: root.theme.iconTokens.lg

        textColor: root.status === "error"
                   ? root.theme.red
                   : (root.status === "printing"
                      ? root.theme.orange
                      : root.theme.accent)

        highlighted: root.jobCount > 0 || root.status === "error"
        tooltipText: String(root.printerData.tooltip ?? "Impressora")

        PrinterPopup {
            id: popup
            theme: root.theme
            target: pill
            printerData: root.printerData
            errorText: root.activeError
            busy: root.actionBusy

            onRefreshRequested: root.refresh()

            onCancelRequested: function(jobId) { root.cancelJob(jobId) }
            onQueueRequested: {
                popup.visible = false
                root.openCupsQueue()
                root.refresh()
            }

            onSettingsRequested: Quickshell.execDetached([
                "sh", "-c",
                "command -v system-config-printer >/dev/null 2>&1 "
                + "&& exec system-config-printer "
                + "|| exec xdg-open http://localhost:631/printers"
            ])
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                popup.visible = !popup.visible
                if (popup.visible)
                    root.refresh()
            } else if (mouse.button === Qt.RightButton) {
                root.refresh()
            }
        }
    }

    function cancelJob(jobId) {
        if (actionProc.busy || jobId.length === 0)
            return

        actionFeedback.begin("")
        actionProc.run(["cancel", jobId])
    }

}
