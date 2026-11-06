pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property bool hyprlandSession: {
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase()
        return desktop.split(":").includes("hyprland")
    }

    // Keep visual motion in Quickshell on every compositor. Hyprland may
    // still animate its own windows and workspaces independently.
    readonly property bool qmlAnimationsEnabled: true
}
