.pragma library

// Shared index-navigation helpers for gallery-style surfaces
// (theme catalog grid, wallpaper carousel). Pure logic, no QML deps.

function clampIndex(idx, length) {
    if (length <= 0)
        return -1
    return Math.min(length - 1, Math.max(0, idx))
}

function findIndex(items, predicate) {
    const list = items ?? []
    for (let i = 0; i < list.length; i++) {
        if (predicate(list[i]))
            return i
    }
    return -1
}

// Grid navigation (e.g. 3-column catalog). Caller resolves an invalid
// starting index (fallback to current item) before calling.
function gridMove(idx, length, cols, dx, dy) {
    if (length <= 0 || cols <= 0)
        return -1
    const row = Math.floor(idx / cols) + dy
    const col = Math.min(cols - 1, Math.max(0, (idx % cols) + dx))
    return clampIndex(row * cols + col, length)
}

// Linear carousel navigation with wrap-around. Out-of-range starts
// over at 0, matching the previous wallpaper behavior.
function linearMove(idx, length, d) {
    if (length <= 0)
        return -1
    if (idx < 0 || idx >= length)
        idx = 0
    return (idx + d + length) % length
}

// Index sync: prefer the current item, else first, else -1 when empty.
function syncIndex(items, isCurrent) {
    const list = items ?? []
    if (list.length === 0)
        return -1
    const at = findIndex(list, isCurrent)
    return at >= 0 ? at : 0
}
