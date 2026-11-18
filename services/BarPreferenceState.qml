pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property string surface: "islands"
    property string error: ""
    property bool loaded: false

    function setSurface(value) {
        if (value !== "islands" && value !== "continuous") return
        root.surface = value
        if (root.loaded) saveDebounce.restart()
    }

    Timer {
        id: saveDebounce
        interval: 180
        repeat: false
        onTriggered: {
            if (saveProc.running) {
                restart()
                return
            }
            saveProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/bar-settings.py", "set", root.surface]
            saveProc.running = true
        }
    }

    Process {
        id: loadProc
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/bar-settings.py", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    if (result.ok && (result.surface === "islands" || result.surface === "continuous"))
                        root.surface = result.surface
                    else if (!result.ok)
                        root.error = String(result.error ?? "Falha ao carregar preferência da barra")
                } catch (error) {
                    root.error = "Resposta inválida ao carregar preferência da barra"
                    console.warn("BarPreferenceState: invalid settings response:", error)
                }
                root.loaded = true
            }
        }
    }

    Process {
        id: saveProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    root.error = result.ok ? "" : String(result.error ?? "Falha ao salvar preferência da barra")
                } catch (error) {
                    root.error = "Resposta inválida ao salvar preferência da barra"
                    console.warn("BarPreferenceState: invalid save response:", error)
                }
            }
        }
    }
}
