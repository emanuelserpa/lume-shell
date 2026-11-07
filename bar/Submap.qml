import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.components

Pill {
    id: root

    property string submap: ""
    readonly property bool hyprlandActive: CompositorState.hyprlandNativeEnabled

    visible: hyprlandActive && submap.length > 0
    text: submap
    tablerIcon: "bar-keyboard"
    iconSize: theme.barIconSize
    fontFamily: theme.fontFamily
    tooltipText: "Atalhos: " + root.submap
    textColor: theme.green

    function normalizeSubmap(value) {
        const s = String(value ?? "").trim()

        if (s.length === 0
            || s === "default"
            || s === "reset"
            || s === "null"
            || s === "none")
            return ""

        return s
    }

    Process {
        id: initialSubmap
        running: root.hyprlandActive
        command: [Quickshell.shellDir + "/scripts/compositor-dispatch.sh", "submap"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.submap = root.normalizeSubmap(this.text)
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: root.hyprlandActive

        function onRawEvent(event) {
            if (event.name === "submap")
                root.submap = root.normalizeSubmap(event.data)
        }
    }
}
