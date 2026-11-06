.pragma library

// Keep the compositor's Windowset objects intact so activation still goes
// through Quickshell's ext-workspace-v1 protocol implementation.
function numericWindowsets(windowsets, maximum) {
    const limit = Math.max(1, Number(maximum) || 1)
    return (windowsets ?? []).filter(function(windowset) {
        const name = String(windowset?.name ?? "")
        return windowset?.shouldDisplay !== false
            && /^[0-9]+$/.test(name)
            && Number(name) >= 1
            && Number(name) <= limit
    }).sort(function(a, b) {
        return Number(a.name) - Number(b.name)
    })
}

function numericWorkspaceNumber(workspace, options) {
    const value = workspace ?? ({})
    const flags = options ?? ({})
    let raw

    if (flags.hyprland && value.id !== undefined)
        raw = value.id
    else if (flags.protocol && value.name !== undefined)
        raw = value.name
    else if (flags.mango && value.number !== undefined)
        raw = value.number
    else if (value.name !== undefined)
        raw = value.name
    else
        raw = value.id

    const number = Number(raw)
    const maximum = Math.max(0, Number(flags.maximum) || 0)
    return Number.isInteger(number) && number >= 1 && number <= maximum
           ? number : 0
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
