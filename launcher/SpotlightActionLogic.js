.pragma library

function groupedActions(actions, groupOrder, filterText) {
    const query = String(filterText ?? "").trim().toLowerCase()
    const entries = []

    for (const group of groupOrder) {
        for (const action of actions ?? []) {
            const matchesGroup = String(action.group ?? "Ações") === group
            const matchesQuery = query.length === 0
                || String(action.title ?? "").toLowerCase().includes(query)
                || String(action.id ?? "").toLowerCase().includes(query)
            if (matchesGroup && matchesQuery)
                entries.push({action: action})
        }
    }

    return entries
}

function actionAt(entries, index) {
    const entry = (entries ?? [])[index]
    return entry?.action ?? null
}

function moveIndex(entries, index, direction) {
    const count = (entries ?? []).length
    if (count === 0)
        return 0

    const current = index >= 0 && index < count ? index : 0
    return (current + direction + count) % count
}

function clipboardValue(actionId, item) {
    if (!item)
        return null
    const data = item.payload ?? item

    switch (String(actionId ?? "")) {
    case "copy-path":
        return data.path ? String(data.path) : null
    case "copy-command": {
        const command = String(data.command ?? data.entry?.execString ?? "")
        return command.length > 0 ? command : null
    }
    case "copy-result":
        return data.value !== undefined ? String(data.value ?? "") : null
    case "copy-expression":
        return data.expression !== undefined ? String(data.expression ?? "") : null
    default:
        return null
    }
}

function resolveCatalogAction(actionId, item, isPrimary, isListed, homeDirectory) {
    if (!item)
        return null

    const id = String(actionId ?? "")
    const kind = String(item.kind ?? "")
    const data = item.payload ?? item

    // URL downloads are action-backed even when “download-video” is the
    // primary action. Resolve them before the generic primary activation.
    if ((id === "download-video" || id === "download-audio")
            && (kind === "url" || kind === "clipboard")) {
        const url = String(kind === "clipboard" ? data.clipboardUrl ?? "" : data.url ?? "").trim()
        if (url.length === 0)
            return null
        return {type: "open-download-panel", url: url,
                mode: id === "download-audio" ? "audio" : "video"}
    }

    if (isPrimary)
        return {type: "activate"}
    const clipboard = clipboardValue(id, item)
    if (clipboard !== null)
        return {type: "copy", value: clipboard}

    if (id === "copy" && kind === "clipboard")
        return {type: "restore-clipboard", stayOpen: true}
    if (id === "open-image" && kind === "clipboard"
            && String(data.clipType ?? "") === "image")
        return {type: "open-clipboard-image"}
    if (id === "copy" && kind === "emoji" && data.emoji)
        return {type: "copy-emoji", emoji: String(data.emoji)}
    if (id === "open-new" && kind === "app"
            && data.entry && typeof data.entry.execute === "function")
        return {type: "execute-entry"}
    if (id === "reveal" && kind === "file" && data.path) {
        const directory = String(data.path).split("/").slice(0, -1).join("/") || "/"
        return {type: "open-directory", directory: directory}
    }
    if (id === "terminal" && kind === "file") {
        const directory = data.path
            ? String(data.path).split("/").slice(0, -1).join("/") || "/"
            : (String(homeDirectory ?? "/") || "/")
        return {type: "open-terminal", directory: directory}
    }
    if (id === "focus" && kind === "window" && isListed
            && ((data.handle && typeof data.handle.activate === "function") || data.address))
        return {type: "focus-window"}
    if (id === "close" && kind === "window"
            && ((data.handle && typeof data.handle.close === "function") || data.address))
        return {type: "close-window"}
    if (id === "delete" && kind === "clipboard")
        return {type: "delete-clipboard"}
    if (id === "retry-download" && kind === "download") {
        const url = String(data.url ?? "").trim()
        if (url.length === 0)
            return null
        return {type: "open-download-panel", url: url,
                mode: String(data.mode ?? "video") === "audio" ? "audio" : "video"}
    }
    if (id === "cancel-download" && kind === "download"
            && String(data.jobId ?? "").length > 0)
        return {type: "cancel-download", jobId: String(data.jobId)}
    if (id === "reveal-download" && kind === "download") {
        const file = String(data.file ?? "")
        const directory = file.length > 0
            ? file.split("/").slice(0, -1).join("/") || "/"
            : String(data.dest ?? "") || "/"
        return {type: "open-directory", directory: directory}
    }

    return null
}
