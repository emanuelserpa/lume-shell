.pragma library

function shouldShowIndicator(updateCount, updateRunning, updateResult) {
    return Number(updateCount) > 0
        || Boolean(updateRunning)
        || String(updateResult ?? "").trim().length > 0
}
