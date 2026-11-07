pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

Item {
    id: root

    required property var popupWindow
    property bool focusGrabEnabled: true
    signal dismissed()

    readonly property bool hyprlandSession: CompositorState.hyprlandNativeEnabled

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
