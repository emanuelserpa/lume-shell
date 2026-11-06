pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import "SpotlightActionLogic.js" as ActionLogic

// Executes Spotlight result actions. Window focus, input navigation, session
// confirmation and app usage remain owned by Spotlight through explicit signals.
Item {
    id: root
    visible: false

    required property var catalog
    required property var clipboardService
    required property var resultItems

    signal closeRequested()
    signal navigateRequested(string prefix)
    signal sessionConfirmationRequested(string action)
    signal downloadPanelRequested(string url, string mode)
    signal usageBumpRequested(string appName)
    signal activateRequested(int index)
    signal systemInfoPopupRequested()

    function markEmojiUsed(value) {
        const char = String(value ?? "")
        if (char.length > 0)
            Quickshell.execDetached([
                "python3", Quickshell.shellDir + "/scripts/launcher-data.py",
                "emoji-mark", char
            ])
    }

    function runSecondary(item, actionId) {
        const wanted = String(actionId ?? "")
        const action = wanted.length > 0
            ? catalog.actionsFor(item).find(function(a) { return String(a.id ?? "") === wanted })
            : catalog.secondaryAction(item)
        if (!action)
            return false
        const operation = ActionLogic.resolveCatalogAction(
            action.id, item, Boolean(action.primary), resultItems.indexOf(item) >= 0,
            Quickshell.env("HOME") ?? "/")
        return dispatchCatalogAction(operation, item)
    }

    function runActionById(actionId, item, selectedIndex) {
        const actions = catalog.actionsFor(item)
        const spec = actions.find(function(a) { return String(a.id ?? "") === String(actionId ?? "") })
        if (!spec)
            return false
        const operation = ActionLogic.resolveCatalogAction(
            spec.id, item, Boolean(spec.primary), resultItems.indexOf(item) >= 0,
            Quickshell.env("HOME") ?? "/")
        return dispatchCatalogAction(operation, item, selectedIndex)
    }

    function dispatchCatalogAction(operation, item, selectedIndex) {
        if (!operation)
            return false
        const data = item.payload ?? item
        switch (operation.type) {
        case "activate": {
            const index = resultItems.indexOf(item)
            activateRequested(index >= 0 ? index : selectedIndex ?? -1)
            return true
        }
        case "copy":
            Quickshell.execDetached(["wl-copy", operation.value])
            return true
        case "restore-clipboard":
            if (operation.stayOpen)
                clipboardService.stayOpenOnce = true
            clipboardService.restore(String(data.clipId ?? ""), String(data.clipSignature ?? ""))
            return true
        case "open-clipboard-image":
            clipboardService.openImage(String(data.clipId ?? ""), String(data.clipSignature ?? ""))
            return true
        case "copy-emoji":
            root.markEmojiUsed(operation.emoji)
            Quickshell.execDetached([
                Quickshell.shellDir + "/scripts/launcher-emoji-copy.sh",
                operation.emoji
            ])
            return true
        case "execute-entry":
            closeRequested()
            data.entry.execute()
            return true
        case "open-directory":
            closeRequested()
            Quickshell.execDetached(["xdg-open", operation.directory])
            return true
        case "open-terminal":
            closeRequested()
            Quickshell.execDetached(["kitty", "--directory", operation.directory])
            return true
        case "focus-window":
            closeRequested()
            if (data.handle && typeof data.handle.activate === "function")
                data.handle.activate()
            else
                Quickshell.execDetached([
                    Quickshell.shellDir + "/scripts/compositor-dispatch.sh",
                    "window",
                    String(data.address),
                    String(data.workspaceName ?? data.workspaceId ?? "")
                ])
            return true
        case "close-window":
            closeRequested()
            if (data.handle && typeof data.handle.close === "function")
                data.handle.close()
            else
                Quickshell.execDetached([
                    Quickshell.shellDir + "/scripts/compositor-dispatch.sh",
                    "close-window",
                    String(data.address)
                ])
            return true
        case "delete-clipboard":
            clipboardService.removeItem(String(data.clipId ?? ""), String(data.clipSignature ?? ""))
            return true
        case "open-download-panel":
            downloadPanelRequested(String(operation.url ?? ""), String(operation.mode ?? "video"))
            return true
        case "cancel-download":
            Quickshell.execDetached([
                "python3", "-B", Quickshell.shellDir + "/scripts/ytdlp-download.py",
                "cancel", String(operation.jobId ?? "")
            ])
            return true
        default:
            return false
        }
    }

    function activate(item) {
        if (!item)
            return
        const data = item.payload ?? item
        if (item.kind === "system_info") {
            systemInfoPopupRequested()
            return
        }
        if (item.kind === "url") {
            downloadPanelRequested(String(data.url ?? ""), "video")
            return
        }
        if (item.kind === "app" && data.entry) {
            const appName = String(data.title ?? data.entry.name ?? "")
            closeRequested()
            usageBumpRequested(appName)
            data.entry.execute()
            return
        }
        if (item.kind === "file" && data.path) {
            const path = data.path
            closeRequested()
            Quickshell.execDetached(["xdg-open", path])
            return
        }
        if (item.kind === "clipboard" && data.clipId !== undefined && data.clipId !== null && String(data.clipId).length > 0) {
            clipboardService.restore(String(data.clipId), String(data.clipSignature ?? ""))
            return
        }
        if (item.kind === "emoji" && data.emoji) {
            root.markEmojiUsed(data.emoji)
            closeRequested()
            Quickshell.execDetached([Quickshell.shellDir + "/scripts/launcher-emoji.sh", data.emoji])
            return
        }
        if (item.kind === "kill" && data.pid) {
            closeRequested()
            Quickshell.execDetached([Quickshell.shellDir + "/scripts/launcher-kill.sh", String(data.pid)])
            return
        }
        if (item.kind === "close_window" && data.handle) {
            closeRequested()
            data.handle.close()
            return
        }
        if (item.kind === "system" && data.command) {
            const command = data.command
            if (String(command[0] ?? "").endsWith("/session-action.sh")) {
                const action = String(command[command.length - 1] ?? "")
                if (["logout", "reboot", "poweroff"].includes(action)) {
                    sessionConfirmationRequested(action)
                    return
                }
            }
            closeRequested()
            Quickshell.execDetached(command)
            return
        }
        if (item.kind === "config_category" && data.prefix) {
            navigateRequested(String(data.prefix))
            return
        }
        if (item.kind === "settings_open") {
            closeRequested()
            Quickshell.execDetached(["quickshell", "ipc", "call", "settings", "open"])
            return
        }
        if (item.kind === "wp_pick" || item.kind === "wp_random") {
            closeRequested()
            Quickshell.execDetached([
                "python3", "-B", Quickshell.shellDir + "/scripts/wallpaper-action.py",
                item.kind === "wp_pick" ? "pick" : "random"
            ])
            return
        }
        if (item.kind === "idle_toggle") {
            IdleState.inhibited = !IdleState.inhibited
            return
        }
        if (item.kind === "power_profile" && data.profile) {
            PowerProfileState.setProfile(data.profile)
            closeRequested()
            return
        }
        if (item.kind === "nightlight_set") {
            NightLightState.setEnabled(Boolean(data.val))
            closeRequested()
            return
        }
        if (item.kind === "restart_quickshell") {
            closeRequested()
            Quickshell.execDetached(["systemctl", "--user", "restart", "quickshell"])
            return
        }
        if (item.kind === "app_exec" && data.command) {
            closeRequested()
            Quickshell.execDetached(data.command)
            return
        }
        if (item.kind === "theme_cycle") {
            closeRequested()
            ThemeState.nextTheme()
            return
        }
        if (item.kind === "nightlight_toggle") {
            closeRequested()
            NightLightState.toggle()
            return
        }
        if (item.kind === "theme_select" && data.themeId) {
            closeRequested()
            ThemeState.setTheme(data.themeId)
            return
        }
        if (item.kind === "command" && data.command.length > 0) {
            const command = data.command
            closeRequested()
            Quickshell.execDetached([Quickshell.shellDir + "/scripts/run-launcher-command.sh", command])
            return
        }
        if (item.kind === "window" && data.handle) {
            closeRequested()
            data.handle.activate()
            return
        }
        if (item.kind === "window" && data.address) {
            closeRequested()
            Quickshell.execDetached([
                Quickshell.shellDir + "/scripts/compositor-dispatch.sh",
                "window",
                String(data.address),
                String(data.workspaceName ?? data.workspaceId ?? "")
            ])
            return
        }
        if (item.kind === "calc") {
            const value = String(data.value ?? "")
            if (value.length > 0)
                Quickshell.execDetached(["wl-copy", value])
            closeRequested()
        }
    }
}
