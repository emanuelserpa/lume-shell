pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property real alpha: 0.68
    property string error: ""

    function setAlpha(value) {
        const normalized = Math.max(0.35, Math.min(0.90, Number(value)))
        root.alpha = Math.round(normalized * 100) / 100
        saveDebounce.restart()
    }

    Timer {
        id: saveDebounce
        interval: 250
        repeat: false
        onTriggered: {
            if (saveProc.running) {
                restart()
                return
            }
            saveProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/glass-settings.py", "set", String(root.alpha)]
            saveProc.running = true
        }
    }

    Process {
        id: loadProc
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/glass-settings.py", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    if (result.ok && Number.isFinite(Number(result.alpha)))
                        root.alpha = Math.max(0.35, Math.min(0.90, Number(result.alpha)))
                    else if (!result.ok)
                        root.error = String(result.error ?? "Falha ao carregar aparência")
                } catch (error) {
                    root.error = "Resposta inválida ao carregar aparência"
                    console.warn("GlassState: invalid settings response:", error)
                }
            }
        }
    }

    Process {
        id: saveProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    root.error = result.ok ? "" : String(result.error ?? "Falha ao salvar aparência")
                } catch (error) {
                    root.error = "Resposta inválida ao salvar aparência"
                    console.warn("GlassState: invalid save response:", error)
                }
            }
        }
    }
}
