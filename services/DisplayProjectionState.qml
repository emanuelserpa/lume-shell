pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

Item {
    id: root

    visible: false
    width: 0
    height: 0

    readonly property bool supported: CompositorState.hyprlandNativeEnabled
    property bool opened: false
    property bool openAfterRefresh: false
    property bool loading: false
    property string error: ""
    property var statusData: ({})
    readonly property var options: statusData.options ?? []
    readonly property bool busy: applyAction.busy

    function toggle() {
        if (!root.supported)
            return
        if (root.opened) {
            root.close()
            return
        }
        root.error = ""
        root.openAfterRefresh = true
        root.refresh()
    }

    function close() {
        root.opened = false
        root.openAfterRefresh = false
    }

    function refresh() {
        if (!root.supported) {
            root.error = "A seleção de projeção requer a integração nativa do Hyprland."
            return
        }
        root.loading = true
        statusCommand.refresh()
    }

    function applyMode(mode) {
        if (root.busy || !root.supported)
            return
        root.error = ""
        applyAction.run(["display-projection", String(mode)])
    }

    function applyStatus(result) {
        root.loading = false
        if (!result || !result.ok) {
            root.error = String(result?.error ?? "Não foi possível consultar os monitores.")
            if (root.openAfterRefresh)
                root.opened = true
            root.openAfterRefresh = false
            return
        }
        root.statusData = result.data ?? ({})
        root.error = ""
        if (root.openAfterRefresh)
            root.opened = true
        root.openAfterRefresh = false
    }

    property IpcHandler ipc: IpcHandler {
        target: "displayProjection"
        function toggle(): void { root.toggle() }
    }

    CommandJson {
        id: statusCommand
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/display-projection.py", "status"]
        interval: 0
        autoStart: false
        onResultChanged: root.applyStatus(statusCommand.result)
    }

    CommandAction {
        id: applyAction
        baseCommand: [Quickshell.shellDir + "/scripts/compositor-dispatch.sh"]
        fallbackError: "Não foi possível alterar o modo das telas."
        refreshTarget: statusCommand

        onSucceeded: {
            root.opened = false
            root.error = ""
        }
        onFailed: root.error = applyAction.error
    }
}
