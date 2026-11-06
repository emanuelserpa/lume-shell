pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services/CompositorBackend.js" as CompositorBackend

Item {
    id: root

    required property var popupWindow
    property bool focusGrabEnabled: true
    signal dismissed()

    readonly property bool hyprlandSession:
        CompositorBackend.kindForDesktop(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "") === "hyprland"

    width: 0
    height: 0
    visible: false

    HyprlandFocusGrab {
        windows: root.focusGrabEnabled && root.hyprlandSession && root.popupWindow?.visible
                 ? [root.popupWindow] : []
        active: root.focusGrabEnabled && root.hyprlandSession && Boolean(root.popupWindow?.visible)
        onCleared: root.dismissed()
    }
}
