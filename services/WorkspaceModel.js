.pragma library

// Keep the compositor's Windowset objects intact so activation still goes
// through Quickshell's ext-workspace-v1 protocol implementation.
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
