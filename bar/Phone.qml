// LEGADO: módulo KDE Connect não montado no shell atual (bar/Bar.qml).
import QtQuick
import Quickshell
import qs.components

Item {
    id: root

    required property var theme

    implicitWidth: root.visible ? pill.implicitWidth : 0
    implicitHeight: root.visible ? (root.theme ? root.theme.pillHeight : 25) : 0
    visible: Boolean(root.phoneData.visible ?? false)

    property alias activeError: actionFeedback.errorText
    property alias activeErrorTarget: actionFeedback.errorTarget
    property alias actionBusyTarget: actionFeedback.busyTarget
    property alias actionBusy: actionFeedback.busy
    readonly property var phoneData: phoneState.result.data

    ActionFeedback { id: actionFeedback }

    CommandJson {
        id: phoneState
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/kdeconnect-status.py"
        ]
        interval: popup.visible ? 5000 : 15000
    }

    function refresh() {
        phoneState.refresh()
    }

    function firstReachableId() {
        const devs = root.phoneData.devices ?? []
        for (let i = 0; i < devs.length; i++) {
            if (Boolean(devs[i].reachable))
                return String(devs[i].id)
        }
        return ""
    }

    function runAction(args, quiet, target) {
        if (actionProc.busy)
            return
        actionFeedback.begin(target, quiet)
        actionProc.run(args)
    }

    CommandAction {
        id: actionProc
        baseCommand: [
            "python3",
            Quickshell.shellDir + "/scripts/kdeconnect-action.py"
        ]
        fallbackError: "A operação falhou."
        refreshTarget: phoneState
        refreshDelay: 800
        onSucceeded: actionFeedback.succeed()
        onFailed: actionFeedback.fail(actionProc.error)
        onFinished: actionFeedback.finish()
    }

    function openSettings() {
        Quickshell.execDetached([
            "sh", "-c",
            "kdeconnect-app 2>/dev/null || kdeconnect-settings 2>/dev/null || plasmawindowed org.kde.kdeconnect 2>/dev/null || true"
        ])
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        text: String(root.phoneData.text ?? "󰏲")
        textColor: Number(root.phoneData.reachable_count ?? 0) > 0 ? root.theme.green : root.theme.grey
        tooltipText: String(root.phoneData.tooltip ?? "Telefone")

        PhonePopup {
            id: popup
            theme: root.theme
            target: pill
            phoneData: root.phoneData
            busy: root.actionBusy
            busyTarget: root.actionBusyTarget
            errorText: root.activeError
            errorTarget: root.activeErrorTarget

            onRefreshRequested: root.refresh()
            onPingRequested: function(id) {
                root.runAction(["ping", id], false, "device:" + id)
            }
            onRingRequested: function(id) {
                root.runAction(["ring", id], false, "device:" + id)
            }
            onPairRequested: function(id) {
                root.runAction(["pair", id], false, "device:" + id)
            }
            onUnpairRequested: function(id) {
                root.runAction(["unpair", id], false, "device:" + id)
            }
            onShareTextRequested: function(id, message) {
                root.runAction(["share-text", id, message], false, "device:" + id)
            }
            onShareFileRequested: function(id, path) {
                root.runAction(["share", id, path], false, "device:" + id)
            }
            onSettingsRequested: root.openSettings()
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                popup.visible = !popup.visible
                if (popup.visible)
                    root.refresh()
            } else if (mouse.button === Qt.RightButton) {
                const id = root.firstReachableId()
                if (id.length > 0)
                    root.runAction(["ping", id], false, "device:" + id)
            }
        }
    }
}
