pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.lockscreen

ShellRoot {
    id: root

    Theme {
        id: lumeTheme
    }

    LockAuth {
        id: authController
        sessionLock: lockController
    }

    Timer {
        id: authenticationStartDelay
        interval: 120
        repeat: false
        onTriggered: authController.startAuthentication()
    }

    WlSessionLock {
        id: lockController
        locked: true

        onSecureChanged: {
            if (secure)
                authenticationStartDelay.restart()
        }

        LockSessionSurface {
            auth: authController
            theme: lumeTheme
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false
        if (lockController.secure)
            authenticationStartDelay.start()
    }
}
