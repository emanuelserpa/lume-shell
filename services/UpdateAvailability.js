.pragma library

function shouldShowIndicator(updateCount, updateRunning) {
    return Number(updateCount) > 0
        || Boolean(updateRunning)
}
