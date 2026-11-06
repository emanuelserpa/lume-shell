pragma Singleton
import QtQuick
import Quickshell
import qs.components

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property string activeError: ""
    property string statusError: ""
    property string lastSaved: ""
    readonly property var recordingData: recordingState.result.data
    property bool recording: false
    property bool hasAudio: false
    property int elapsed: 0
    readonly property string elapsedText: root.timeLabel(root.elapsed)
    readonly property string errorText: root.activeError.length > 0 ? root.activeError : root.statusError
    readonly property bool busy: actionProc.busy
    property string pendingMode: ""
    property string pendingAudioMode: "none"
    property string audioMode: "none"

    signal recordingStopped()
    signal startFailed(string error)

    function timeLabel(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds ?? 0)))
        const minutes = Math.floor(total / 60)
        const remaining = total % 60
        return minutes + ":" + String(remaining).padStart(2, "0")
    }

    function action(command) {
        if (actionProc.busy)
            return
        root.activeError = ""
        root.statusError = ""
        root.lastSaved = ""
        actionProc.run(command)
    }

    function requestStart(mode, selectedAudioMode) {
        root.pendingMode = mode
        root.pendingAudioMode = selectedAudioMode
        root.audioMode = selectedAudioMode
        selectionDelay.restart()
    }

    function stop() {
        root.action(["stop"])
    }

    CommandJson {
        id: recordingState
        command: ["python3", Quickshell.shellDir + "/scripts/screen-recording.py", "status"]
        interval: root.recording ? 2000 : 5000
        onResultChanged: {
            const result = recordingState.result
            const data = result.data ?? ({})
            const isActive = Boolean(result.ok && data.active)
            const wasActive = root.recording
            root.recording = isActive
            root.hasAudio = isActive && Boolean(data.audio)
            if (isActive) {
                const reportedElapsed = Math.max(0, Number(data.elapsed ?? 0))
                root.elapsed = wasActive ? Math.max(root.elapsed, reportedElapsed) : reportedElapsed
            } else {
                root.elapsed = 0
            }
            root.statusError = !result.ok && result.error !== "Aguardando resposta."
                ? String(result.error || "Falha ao consultar a gravação.")
                : ""
        }
    }

    Timer {
        id: elapsedTicker
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed += 1
    }

    CommandAction {
        id: actionProc
        baseCommand: ["python3", Quickshell.shellDir + "/scripts/screen-recording.py"]
        refreshTarget: recordingState
        onSucceeded: {
            const result = actionProc.result.data ?? ({})
            if (Boolean(result.active)) {
                root.recording = true
                root.hasAudio = Boolean(result.audio)
                root.elapsed = Math.max(0, Number(result.elapsed ?? 0))
            } else {
                root.recording = false
                root.hasAudio = false
                root.elapsed = 0
                if (result.path)
                    root.lastSaved = String(result.path)
                root.recordingStopped()
            }
        }
        onFailed: {
            root.activeError = actionProc.error
            if (root.activeError !== "Seleção cancelada.")
                root.startFailed(root.activeError)
        }
    }

    Timer {
        id: selectionDelay
        interval: 180
        repeat: false
        onTriggered: {
            const args = ["start", root.pendingMode, "--audio-mode", root.pendingAudioMode]
            root.action(args)
        }
    }
}
