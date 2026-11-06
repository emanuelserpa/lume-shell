.pragma library

function consumeStartedStop(process) {
    if (process.running) {
        process.observedStart = true
        return false
    }

    if (!process.observedStart)
        return false

    process.observedStart = false
    return true
}
