.pragma library

// Keep the compositor's Windowset objects intact so activation still goes
// through Quickshell's ext-workspace-v1 protocol implementation.
function visibleWindowsets(windowsets, excludeOverview) {
    return (windowsets ?? []).filter(function(windowset) {
        const name = String(windowset?.name ?? "")
        return windowset?.shouldDisplay !== false
            && !(excludeOverview && name.toLowerCase() === "overview")
    })
}

function numericWindowsets(windowsets, maximum) {
    const parsedLimit = Number(maximum)
    const limit = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : null
    return (windowsets ?? []).filter(function(windowset) {
        const name = String(windowset?.name ?? "")
        return windowset?.shouldDisplay !== false
            && /^[0-9]+$/.test(name)
            && Number(name) >= 1
            && (limit === null || Number(name) <= limit)
    }).sort(function(a, b) {
        return Number(a.name) - Number(b.name)
    })
}

function numericWorkspaceNumber(workspace, options) {
    const settings = options ?? {}
    let raw
    if (settings.hyprland)
        raw = workspace?.id
    else if (settings.protocol)
        raw = workspace?.name
    else if (settings.mango)
        raw = workspace?.number ?? workspace?.name ?? workspace?.id
    else
        raw = workspace?.number ?? workspace?.id ?? workspace?.name

    const value = Number(raw)
    const maximum = Number(settings.maximum)
    if (!Number.isInteger(value) || value < 1
            || (Number.isFinite(maximum) && maximum > 0 && value > maximum))
        return 0
    return value
}

function adjacentWindowset(windowsets, currentName, direction) {
    const values = windowsets ?? []
    if (values.length < 2)
        return null

    const currentIndex = values.findIndex(function(windowset) {
        return String(windowset?.name ?? "") === String(currentName ?? "")
    })
    if (currentIndex < 0)
        return null

    const step = Number(direction) < 0 ? -1 : 1
    const nextIndex = (currentIndex + step + values.length) % values.length
    return values[nextIndex] ?? null
}

function hasHyprlandWindows(workspace) {
    const snapshotCount = Number(workspace?.lastIpcObject?.windows ?? 0)
    if (Number.isFinite(snapshotCount) && snapshotCount > 0)
        return true

    const toplevels = workspace?.toplevels?.values
    return Array.isArray(toplevels) && toplevels.length > 0
}

function isHyprlandWorkspaceActiveOnMonitor(workspace, monitor) {
    if (!workspace)
        return false

    const monitorWorkspace = monitor?.activeWorkspace
    if (monitorWorkspace !== null && monitorWorkspace !== undefined) {
        if (workspace.id !== undefined && monitorWorkspace.id !== undefined)
            return Number(workspace.id) === Number(monitorWorkspace.id)
        return String(workspace.name ?? "") === String(monitorWorkspace.name ?? "")
    }

    // Older Quickshell builds may not expose the per-monitor workspace yet.
    return Boolean(workspace.active)
}
