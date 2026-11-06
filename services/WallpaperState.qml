pragma Singleton
import QtQuick
import Quickshell
import qs.components

// Shared wallpaper gallery state (wallpaper-action.py backend).
// Consumed by the launcher ThemePreviewPane and the settings window;
// delegate-coupled flows (preview queue, folder picker UI) stay local.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var wpItems: []
    property string activeWallpaper: ""
    property bool isWorking: false
    property string statusMessage: ""
    property string actionError: ""
    property string pendingKind: ""

    signal actionDone(bool ok, string kind)
    signal galleryChanged()

    function refreshGallery() {
        listState.refresh()
    }

    function applyWallpaper(path) {
        runKind("apply", ["apply", String(path ?? "")])
    }

    function pickWallpaper() {
        runKind("pick", ["pick"])
    }

    function randomWallpaper() {
        runKind("random", ["random"])
    }

    function runKind(kind, args) {
        if (root.isWorking)
            return
        root.isWorking = true
        root.statusMessage = "Processando..."
        root.actionError = ""
        root.pendingKind = kind
        runAction.run(args)
    }

    function clearStatus() {
        root.statusMessage = ""
    }

    Timer {
        id: statusTimer
        interval: 3500
        repeat: false
        onTriggered: root.clearStatus()
    }

    CommandJson {
        id: listState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/wallpaper-action.py", "list"]
        interval: 0
        autoStart: false
        onResultChanged: {
            const res = listState.result
            if (res.ok && Array.isArray(res.data.items)) {
                root.wpItems = res.data.items
                const cur = root.wpItems.find(function(item) { return item.current })
                if (cur && cur.path)
                    root.activeWallpaper = String(cur.path)
            } else if (!res.ok) {
                root.actionError = String(res.error ?? "")
            }
            root.galleryChanged()
        }
    }

    CommandAction {
        id: runAction
        baseCommand: ["python3", "-B", Quickshell.shellDir + "/scripts/wallpaper-action.py"]
        onSucceeded: {
            const data = runAction.result.data ?? ({})
            if (data.wallpaper)
                root.activeWallpaper = String(data.wallpaper)
            root.isWorking = false
            root.statusMessage = ""
            root.refreshGallery()
            root.actionDone(true, root.pendingKind)
        }
        onFailed: {
            root.actionError = runAction.error
            root.statusMessage = runAction.error
            root.isWorking = false
            statusTimer.restart()
            root.actionDone(false, root.pendingKind)
        }
    }
}
