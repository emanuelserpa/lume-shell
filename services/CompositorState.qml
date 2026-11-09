pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.WindowManager
import "CompositorBackend.js" as CompositorBackend

QtObject {
    id: root

    readonly property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP") ?? ""
    readonly property string sessionKind: CompositorBackend.kindForDesktop(root.desktop)
    readonly property string requestedMode:
        String(Quickshell.env("LUME_COMPOSITOR_MODE") ?? "auto").trim().toLowerCase()
    readonly property bool modeValid: ["auto", "wayland", "hyprland"].includes(root.requestedMode)
    readonly property string effectiveMode: root.modeValid ? root.requestedMode : "auto"
    readonly property bool hyprlandSession: root.sessionKind === "hyprland"
    readonly property bool mangoSession: root.sessionKind === "mango"
    readonly property bool hyprlandNativeEnabled:
        root.hyprlandSession && root.effectiveMode !== "wayland"
    readonly property bool mangoCompatibilityEnabled:
        root.mangoSession && root.effectiveMode === "auto"
    readonly property string configurationError: {
        if (!root.modeValid)
            return "LUME_COMPOSITOR_MODE deve ser auto, wayland ou hyprland."
        if (root.effectiveMode === "hyprland" && !root.hyprlandSession)
            return "O modo hyprland foi solicitado fora de uma sessão Hyprland."
        return ""
    }

    readonly property int protocolWorkspaceCount: WindowManager.windowsets.length
    readonly property int protocolToplevelCount: ToplevelManager.toplevels.values.length
    readonly property string workspaceProtocolState:
        root.protocolWorkspaceCount > 0 ? "ready" : "unreported"
    readonly property string toplevelProtocolState:
        root.protocolToplevelCount > 0 ? "ready" : "unreported"
    readonly property string workspaceProvider:
        root.hyprlandNativeEnabled ? "hyprland" : "ext-workspace-v1"
    readonly property string toplevelProvider:
        root.hyprlandNativeEnabled ? "hyprland-with-foreign-toplevel-fallback"
                                   : "zwlr-foreign-toplevel-management-v1"

    readonly property var capabilities: ({
        layerShell: "provided-by-quickshell",
        workspaces: root.workspaceProtocolState,
        toplevels: root.toplevelProtocolState,
        outputManagement: "not-exposed-by-current-quickshell-api",
        focusedOutput: root.hyprlandNativeEnabled ? "hyprland"
                      : root.mangoCompatibilityEnabled ? "mmsg"
                      : "first-output-fallback"
    })

    Component.onCompleted: {
        if (root.configurationError.length > 0)
            console.warn(root.configurationError)
        if (root.effectiveMode === "hyprland" && root.hyprlandSession)
            console.info("Lume compositor mode: Hyprland native integration")
        else
            console.info("Lume compositor mode: Wayland protocol providers")
    }

    function protocolWindowItems() {
        return ToplevelManager.toplevels.values.map(function(window) {
            return {
                title: window.title || window.appId || "Janela",
                class: window.appId || "Aplicativo",
                handle: window,
                pid: "",
                workspaceName: ""
            }
        })
    }

    function activateToplevel(handle) {
        if (!handle)
            return false
        try {
            if (typeof handle.activate !== "function")
                return false
            handle.activate()
            return true
        } catch (error) {
            console.warn("Wayland window activation request failed:", error)
            return false
        }
    }

    function closeToplevel(handle) {
        if (!handle)
            return false
        try {
            if (typeof handle.close !== "function")
                return false
            handle.close()
            return true
        } catch (error) {
            console.warn("Wayland window close request failed:", error)
            return false
        }
    }

    property Timer workspaceRefreshTimer: Timer {
        interval: 50
        repeat: false
        onTriggered: Hyprland.refreshWorkspaces()
    }

    property Timer monitorRefreshTimer: Timer {
        interval: 50
        repeat: false
        onTriggered: Hyprland.refreshMonitors()
    }

    property Connections hyprlandRefreshEvents: Connections {
        target: root.hyprlandNativeEnabled ? Hyprland : null

        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2"].includes(event.name))
                root.workspaceRefreshTimer.restart()

            if (["workspace", "workspacev2", "focusedmon", "focusedmonv2"]
                    .includes(event.name))
                root.monitorRefreshTimer.restart()
        }
    }
}
