pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.osd
import qs.launcher
import qs.notifications
import qs.services

ShellRoot {
    Component.onCompleted: {
        BatteryAlertState.start()
        NightLightState.syncSession()
    }

    Process {
        id: pathMigrationProc
        running: true
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/migrate-paths.py"]
    }

    ClipboardService {
        id: clipboardService
    }

    Spotlight {
        id: spotlight
    }

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
            launcherController: spotlight
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Osd {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: NotificationToasts {
            required property var modelData
            screen: modelData
        }
    }
}
