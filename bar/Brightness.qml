// LEGADO: componente não montado no shell atual (substituído pelo SliderRow em bar/NotificationPopup.qml e pelo OSD em osd/Osd.qml).
import QtQuick
import Quickshell
import qs.components

Pill {
    id: root

    property int brightness: 0
    property bool available: false
    property string deviceName: ""
    property string errorText: ""
    property bool changing: false

    function iconFor(value) {
        if (value <= 25) return "󰃞"
        if (value <= 65) return "󰃟"
        return "󰃠"
    }

    function refresh() {
        if (!root.changing)
            brightnessState.refresh()
    }

    function setBrightness(value) {
        if (!root.available || root.changing)
            return

        const v = Math.max(1, Math.min(100, Math.round(value)))
        root.brightness = v
        root.errorText = ""
        root.changing = true
        setAction.run(["set", String(v)])
    }

    function settleSet() {
        root.changing = false
        refreshDelay.restart()
    }

    function changeBrightness(delta) {
        setBrightness(root.brightness + delta)
    }

    text: root.available
          ? root.iconFor(root.brightness) + " " + root.brightness + "%"
          : "󰃠 --%"

    textColor: root.available ? theme.yellow : theme.grey
    highlighted: false

    tooltipText: root.available
                 ? "Brilho da tela · " + root.brightness + "%"
                 : "Brilho indisponível"

    CommandJson {
        id: brightnessState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/brightness-status.py"]
        interval: root.changing ? 0 : 2500
        onPayloadChanged: {
            const result = brightnessState.payload ?? ({})
            root.available = Boolean(result.ok) && Boolean(result.available)
            root.deviceName = String(result.device ?? "")
            if (root.available)
                root.brightness = Math.max(0, Math.min(100, Number(result.brightness ?? 0)))
            else if (!root.changing)
                root.brightness = 0
            if (!result.ok && result.error)
                root.errorText = String(result.error)
        }
    }

    CommandAction {
        id: setAction
        baseCommand: ["python3", "-B", Quickshell.shellDir + "/scripts/brightness-action.py"]
        fallbackError: "Não foi possível alterar o brilho."
        onSucceeded: root.settleSet()
        onFailed: {
            root.errorText = setAction.error
            root.settleSet()
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: false
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    BrightnessPopup {
        id: popup
        theme: root.theme
        target: root
        brightness: root.brightness
        available: root.available
        deviceName: root.deviceName
        errorText: root.errorText
        onBrightnessRequested: function(value) {
            root.setBrightness(value)
        }
    }

    mouseArea.onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton)
            popup.visible = !popup.visible
    }

    mouseArea.onWheel: function(wheel) {
        if (!root.available) return
        root.changeBrightness(wheel.angleDelta.y > 0 ? 5 : -5)
    }
}
