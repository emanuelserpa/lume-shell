.pragma library

// Normalize Mango's versioned native IPC snapshot into a compositor-neutral
// output/tag shape consumed by the shell UI.
function normalizeSnapshot(snapshot) {
    if (!snapshot)
        return null

    // Mango 0.17 exposes `all_tags` with `monitor` names. Keep accepting the
    // earlier normalized `monitors` shape for fixtures and compatibility.
    const monitors = Array.isArray(snapshot.monitors)
        ? snapshot.monitors
        : Array.isArray(snapshot.all_tags)
            ? snapshot.all_tags
            : null
    if (!monitors)
        return null

    const outputs = {}
    let focusedOutput = ""

    monitors.forEach(function(monitor) {
        const name = String(monitor?.name ?? monitor?.monitor ?? "").trim()
        if (!name)
            return

        const activeTagIds = Array.isArray(monitor.active_tags)
            ? monitor.active_tags.map(Number)
            : []
        const tags = Array.isArray(monitor.tags) ? monitor.tags.map(function(tag) {
            const number = Number(tag?.index ?? tag?.tag ?? tag?.id)
            if (!Number.isInteger(number) || number < 1 || number > 9)
                return null

            const clients = Math.max(0, Number(tag.client_count ?? tag.clients ?? 0) || 0)
            const active = Boolean(tag.is_active ?? tag.active ?? tag.state === 1)
                || activeTagIds.includes(number)
            const urgent = Boolean(tag.is_urgent ?? tag.urgent ?? tag.state === 2)

            return {
                number: number,
                active: active,
                urgent: urgent,
                occupied: clients > 0,
                clientCount: clients
            }
        }).filter(function(tag) { return tag !== null }) : []

        outputs[name] = {
            name: name,
            focused: Boolean(monitor.active ?? monitor.focused ?? monitor.is_focused),
            tags: tags
        }

        if (outputs[name].focused)
            focusedOutput = name
    })

    return { version: 1, provider: "mango-mmsg", outputs: outputs, focusedOutput: focusedOutput }
}

function visibleTags(output) {
    if (!output || !Array.isArray(output.tags))
        return []
    return output.tags.filter(function(tag) {
        return tag.active || tag.occupied || tag.urgent
    }).sort(function(a, b) { return a.number - b.number })
}

function adjacentTag(currentNumber, direction, tagCount) {
    const current = Number(currentNumber)
    const count = Number(tagCount)
    if (!Number.isInteger(current) || !Number.isInteger(count) || count < 1
        || current < 1 || current > count)
        return null
    return ((current - 1 + (direction < 0 ? -1 : 1) + count) % count) + 1
}
