import QtQuick
import Quickshell
import qs.components
import qs.services

// Etapa 5 do fatiamento do Spotlight: fontes de busca por modo
// (arquivos `@`, emojis `;`, janelas `~`/`!`). Cada seção é dona do seu
// processo, estado e debounce. O Spotlight continua dono dos atalhos,
// do ciclo de vida da janela, dos prefixos de modo e da exibição.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    // ---- Arquivos (@) ----
    property var fileItems: []
    property string pendingFileQuery: ""

    function searchFiles(query) {
        root.pendingFileQuery = String(query ?? "")
        fileSearchDelay.restart()
    }

    CommandJson {
        id: fileSearchProc
        interval: 0
        autoStart: false
        onResultChanged: {
            const response = fileSearchProc.result
            root.fileItems = response.ok && Array.isArray(response.data.items)
                             ? response.data.items : []
        }
    }

    Timer {
        id: fileSearchDelay
        interval: 120
        repeat: false

        onTriggered: {
            const value = root.pendingFileQuery.trim()
            if (!value.startsWith("@"))
                return

            const q = value.slice(1).trim()
            if (q.length < 2) {
                root.fileItems = []
                return
            }

            fileSearchProc.command = [
                "python3",
                Quickshell.shellDir + "/scripts/launcher-data.py",
                "files",
                q
            ]
            fileSearchProc.restart()
        }
    }

    // ---- Emojis (;) ----
    property var emojiItems: []
    property bool emojiAvailable: true
    property string pendingEmojiQuery: ""

    function searchEmoji(query) {
        root.pendingEmojiQuery = String(query ?? "")
        emojiSearchDelay.restart()
    }

    CommandJson {
        id: emojiProc
        interval: 0
        autoStart: false
        onResultChanged: {
            const response = emojiProc.result
            root.emojiAvailable = response.ok && response.data.available !== false
            root.emojiItems = response.ok && Array.isArray(response.data.items)
                              ? response.data.items : []
        }
    }

    Timer {
        id: emojiSearchDelay
        interval: 90
        repeat: false

        onTriggered: {
            const value = root.pendingEmojiQuery.trim()
            if (!value.startsWith(";"))
                return

            const q = value.slice(1).trim()

            emojiProc.command = [
                "python3",
                Quickshell.shellDir + "/scripts/launcher-data.py",
                "emoji",
                q
            ]
            emojiProc.restart()
        }
    }

    // ---- Janelas (~/!) ----
    property var windowItems: []
    property var killItems: []
    readonly property bool hyprlandNativeWindowProviderActive:
        CompositorState.hyprlandNativeEnabled

    function protocolWindowItems() {
        return CompositorState.protocolWindowItems()
    }

    function refreshWindows() {
        if (root.hyprlandNativeWindowProviderActive) {
            // Prefer Hyprland's native client metadata, including workspace
            // and PID fields that foreign-toplevel intentionally omits.
            windowRefreshDelay.restart()
            return
        }

        // The same Quickshell foreign-toplevel provider serves every
        // compositor when its native Hyprland metadata is not selected.
        root.windowItems = root.protocolWindowItems()
        root.killItems = root.windowItems
    }

    CommandJson {
        id: windowsProc
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "windows"
        ]
        interval: 0
        autoStart: false
        onResultChanged: {
            const response = windowsProc.result
            const items = response.ok && Array.isArray(response.data.items)
                          ? response.data.items : []
            if (items.length > 0) {
                root.windowItems = items
                root.killItems = items
            } else {
                root.windowItems = root.protocolWindowItems()
                root.killItems = root.windowItems
            }
        }
    }

    Timer {
        id: windowRefreshDelay
        interval: 60
        repeat: false
        onTriggered: windowsProc.refresh()
    }
}
