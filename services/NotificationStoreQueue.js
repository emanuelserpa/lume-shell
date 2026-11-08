.pragma library

function enqueue(queue, request, limit) {
    const next = Array.isArray(queue) ? queue.slice() : []
    const cap = Math.max(1, Math.floor(Number(limit) || 1))
    const op = String(request?.op ?? "")

    // A clear supersedes every operation that has not reached the store yet.
    if (op === "clear")
        return { queue: [request], dropped: 0, rejected: false }

    let dropped = 0
    if (next.length >= cap) {
        const oldestAppend = next.findIndex(item => String(item?.op ?? "") === "append")
        if (oldestAppend >= 0) {
            next.splice(oldestAppend, 1)
            dropped = 1
        } else {
            // Preserve queued control operations when no append can be evicted.
            return { queue: next, dropped: 1, rejected: true }
        }
    }

    next.push(request)
    return { queue: next, dropped: dropped, rejected: false }
}

function retryDelay(attempt, maxDelay) {
    const count = Math.max(1, Math.floor(Number(attempt) || 1))
    const ceiling = Math.max(1000, Math.floor(Number(maxDelay) || 60000))
    return Math.min(1000 * Math.pow(2, count - 1), ceiling)
}
