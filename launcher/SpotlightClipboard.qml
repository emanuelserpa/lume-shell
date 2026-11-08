import QtQuick
import Quickshell
import Quickshell.Io
import "../services/CommandResult.js" as CommandResult

// Etapa 3 do fatiamento do Spotlight: controlador local do clipboard.
// Dono de snapshot, miniaturas, restauração e remoção. O Spotlight
// continua dono de abrir o modo `#`, apresentar o estado, da seleção e
// de fechar a janela (via restoreSucceeded).
Item {
    id: root
    visible: false
    width: 0
    height: 0

    // Ligado pelo Spotlight ao modo `#`.
    property bool active: false
    // Quando true, o próximo restore bem-sucedido não fecha o launcher
    // (ação secundária "copiar sem fechar" da Etapa 1 Raycast).
    property bool stayOpenOnce: false
    // Resultados visíveis no momento (para pedir só miniaturas úteis).
    property var visibleResults: []

    property var items: []
    property var thumbs: ({})
    property bool available: true
    property bool loaded: false
    property bool fresh: false
    property string restoreError: ""
    property string error: ""
    property bool capturePaused: false
    property bool capturePauseKnown: false
    property bool captureControlRunning: false
    property string captureControlError: ""
    property bool deleteRunning: false
    property bool pendingChange: false
    readonly property bool restoreRunning: restoreProc.running
    readonly property bool imageOpenRunning: imageOpenProc.running
    readonly property bool snapshotRunning: snapshotProc.running

    signal restoreSucceeded()
    signal imageOpenSucceeded()
    signal itemsReplacing()
    signal itemsReplaced()

    onActiveChanged: {
        if (!active) {
            changeDelay.stop()
            pendingChange = false
        } else {
            root.refreshCaptureState()
        }
    }

    function refreshCaptureState() {
        if (captureControlProc.running)
            return
        captureControlError = ""
        captureControlProc.command = [
            "python3", Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-capture-state"
        ]
        captureControlProc.running = true
    }

    function setCapturePaused(paused) {
        if (captureControlProc.running)
            return false
        captureControlError = ""
        captureControlProc.command = [
            "python3", Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-capture", paused ? "pause" : "resume"
        ]
        captureControlProc.running = true
        return true
    }

    FileView {
        id: changeFile
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
              + "/quickshell/clipboard-change"
        watchChanges: root.active
        printErrors: false
        onFileChanged: {
            this.reload()
            if (root.active)
                changeDelay.restart()
        }
    }

    Timer {
        id: changeDelay
        interval: 90
        repeat: false
        onTriggered: {
            if (snapshotProc.running)
                root.pendingChange = true
            else if (root.active)
                root.refresh()
        }
    }

    function refresh() {
        // Keep the previous list visible while the database snapshot refreshes.
        root.loaded = root.items.length > 0
        root.fresh = false
        root.restoreError = ""

        if (snapshotProc.running)
            snapshotProc.running = false
        if (thumbProc.running)
            thumbProc.running = false

        snapshotProc.running = true
    }

    function removeItem(clipId, clipSignature) {
        const targetId = String(clipId ?? "")
        if (targetId.length === 0 || deleteProc.running)
            return

        root.deleteRunning = true
        root.restoreError = ""

        // Instant local removal
        root.items = root.items.filter(function(ci) {
            return String(ci.id) !== targetId
        })

        deleteProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-remove",
            targetId,
            String(clipSignature ?? "")
        ]
        deleteProc.running = true
    }

    function restore(clipId, clipSignature) {
        const targetId = String(clipId ?? "")
        if (targetId.length === 0 || restoreProc.running)
            return

        root.restoreError = ""
        restoreProc.command = [
            Quickshell.shellDir + "/scripts/launcher-clipboard.sh",
            targetId,
            String(clipSignature ?? "")
        ]
        restoreProc.running = true
    }

    function openImage(clipId, clipSignature) {
        const targetId = String(clipId ?? "")
        if (targetId.length === 0 || imageOpenProc.running)
            return

        root.restoreError = ""
        imageOpenProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-open-image",
            targetId,
            String(clipSignature ?? "")
        ]
        imageOpenProc.running = true
    }

    function scheduleThumbnails() {
        if (root.active)
            thumbDelay.restart()
    }

    function requestThumbnails() {
        if (!root.active || !root.fresh)
            return

        const requests = []
        const shown = root.visibleResults

        for (let i = 0; i < shown.length && requests.length < 24; ++i) {
            const item = shown[i]

            if (String(item.kind ?? "") !== "clipboard"
                    || String(item.clipType ?? "") !== "image")
                continue

            const id = String(item.clipId ?? "")
            const mime = String(item.mime ?? "")

            if (id.length === 0 || mime.length === 0)
                continue

            if (String(root.thumbs[id] ?? "").length > 0)
                continue

            requests.push({ id: id, mime: mime })
        }

        if (requests.length === 0 || thumbProc.running)
            return

        thumbProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-thumbnails",
            JSON.stringify(requests)
        ]
        thumbProc.running = true
    }

    Process {
        id: snapshotProc
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-snapshot",
            "200"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                const data = response.data
                root.available = response.ok && data.available !== false
                root.error = String(response.error ?? data.error ?? "")
                root.itemsReplacing()
                root.items = Array.isArray(data.items) ? data.items : []
                root.itemsReplaced()
                root.loaded = true
                root.fresh = true
                root.restoreError = ""
                root.scheduleThumbnails()
                if (root.pendingChange && root.active) {
                    root.pendingChange = false
                    root.refresh()
                }
            }
        }
    }

    Process {
        id: restoreProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                if (response.ok)
                    root.restoreSucceeded()
                else
                    root.restoreError = response.error || "Item mudou · reabra o clipboard"
            }
        }
    }

    Process {
        id: deleteProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.deleteRunning = false
                const response = CommandResult.decode(this.text)
                if (!response.ok)
                    root.restoreError = response.error || "Não foi possível remover"
            }
        }
    }

    Process {
        id: imageOpenProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                if (response.ok)
                    root.imageOpenSucceeded()
                else
                    root.restoreError = response.error || "Não foi possível abrir a imagem"
            }
        }
    }

    Process {
        id: thumbProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                if (response.ok) {
                    const incoming = response.data.thumbnails ?? ({})
                    root.thumbs = Object.assign({}, root.thumbs, incoming)
                }
            }
        }
    }

    Timer {
        id: thumbDelay
        interval: 70
        repeat: false
        onTriggered: root.requestThumbnails()
    }

    Process {
        id: captureControlProc
        command: [
            "python3", Quickshell.shellDir + "/scripts/launcher-data.py",
            "clipboard-capture-state"
        ]
        onRunningChanged: root.captureControlRunning = running
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                const data = response.data
                if (response.ok && typeof data.paused === "boolean") {
                    root.capturePaused = data.paused
                    root.capturePauseKnown = true
                    root.captureControlError = ""
                } else {
                    root.captureControlError = String(response.error || "Falha ao atualizar captura.")
                }
            }
        }
    }
}
