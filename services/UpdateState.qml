pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Single source of truth for system-update counts. The bar pill and its popup
// consume this state so each backend is queried once per interval.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool updateRunning: false
    property string updateMessage: ""
    property string updateResult: ""
    property bool updateSucceeded: false
    property int updateStage: 0
    property int updateStageCount: 0
    property int updateProgress: -1
    property string activeBackend: "all"
    property bool receivedFinalStatus: false

    function startUpdate(backend) {
        if (root.updateRunning) return false
        root.activeBackend = String(backend || "all")
        root.updateRunning = true
        root.updateMessage = "Preparando atualização…"
        root.updateResult = ""
        root.updateSucceeded = false
        root.updateStage = 0
        root.updateStageCount = 0
        root.updateProgress = -1
        root.receivedFinalStatus = false
        updateProcess.running = true
        return true
    }

    function restoreLastResult() {
        if (!savedResultProcess.running)
            savedResultProcess.running = true
    }

    Component.onCompleted: root.restoreLastResult()

    function receiveUpdateStatus(line) {
        try {
            const status = JSON.parse(String(line).trim())
            if (status.type === "stage") {
                root.updateStage = Number(status.step ?? 0)
                root.updateStageCount = Number(status.total ?? 0)
                root.updateProgress = -1
                const text = String(status.text ?? "Atualizando…")
                root.updateMessage = root.updateStageCount > 1
                    ? root.updateStage + "/" + root.updateStageCount + " · " + text
                    : text
            } else if (status.type === "progress") {
                root.updateProgress = Math.max(0, Math.min(100, Number(status.percent ?? 0)))
                const item = Number(status.item ?? 0)
                const items = Number(status.items ?? 0)
                root.updateMessage = "Flatpak · " + item + "/" + items
                    + " · " + root.updateProgress + "%"
            } else if (status.type === "done") {
                root.receivedFinalStatus = true
                root.updateRunning = false
                root.updateProgress = -1
                root.updateResult = String(status.text ?? "Atualização concluída.")
                root.updateSucceeded = Boolean(status.ok)
                root.updateMessage = root.updateResult
                root.refreshUpdates()
            }
        } catch (error) {
            console.warn("UpdateState: resposta de atualização inválida:", error)
        }
    }

    CommandJson {
        id: archUpdates
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/arch-updates.sh"]
        interval: 3600000
    }

    Process {
        id: updateProcess
        command: ["bash", Quickshell.shellDir + "/scripts/system-update.sh", root.activeBackend]
        running: false

        stdout: SplitParser {
            onRead: function(line) { root.receiveUpdateStatus(line) }
        }

        onExited: function(exitCode, exitStatus) {
            if (root.receivedFinalStatus) return
            root.updateRunning = false
            root.updateResult = exitCode === 0
                ? "Atualização concluída."
                : "A atualização terminou com erro (" + exitCode + ")."
            root.updateSucceeded = exitCode === 0
            root.updateMessage = root.updateResult
            root.refreshUpdates()
        }
    }

    Process {
        id: savedResultProcess
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/update-log.py", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim())
                    const data = response?.data ?? {}
                    if (response?.ok && data.has_status && !root.updateRunning) {
                        root.updateResult = String(data.text ?? "")
                        root.updateSucceeded = Boolean(data.succeeded)
                        root.updateMessage = root.updateResult
                    }
                } catch (error) {
                    console.warn("UpdateState: não foi possível restaurar o último resultado:", error)
                }
            }
        }
    }

    CommandJson {
        id: aurUpdates
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/aur-updates.sh"]
        interval: 3600000
    }

    CommandJson {
        id: flatpakUpdates
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/flatpak-updates.sh"]
        interval: 3600000
    }

    CommandJson {
        id: brewUpdates
        command: ["sh", "-c", Quickshell.shellDir + "/scripts/brew-updates.sh"]
        interval: 3600000
    }

    CommandJson {
        id: appImageUpdates
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/gearlever-updates.py"]
        interval: 3600000
    }

    readonly property int archCount: Number(archUpdates.result.data.count ?? 0)
    readonly property int aurCount: Number(aurUpdates.result.data.count ?? 0)
    readonly property int flatpakCount: Number(flatpakUpdates.result.data.count ?? 0)
    readonly property int brewCount: Number(brewUpdates.result.data.count ?? 0)
    readonly property int appImageCount: Number(appImageUpdates.result.data.count ?? 0)
    readonly property int totalUpdates: archCount + aurCount + flatpakCount + brewCount + appImageCount

    readonly property var repoData: archUpdates.result.data
    readonly property var aurData: aurUpdates.result.data
    readonly property var flatpakData: flatpakUpdates.result.data
    readonly property var brewData: brewUpdates.result.data
    readonly property var appImageData: appImageUpdates.result.data

    function refreshUpdates() {
        archUpdates.refresh()
        aurUpdates.refresh()
        flatpakUpdates.refresh()
        brewUpdates.refresh()
        appImageUpdates.refresh()
    }
}
