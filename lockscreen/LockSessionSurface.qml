pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

WlSessionLockSurface {
    id: root

    required property var auth
    required property var theme

    LockSurface {
        anchors.fill: parent
        auth: root.auth
        theme: root.theme
    }
}
