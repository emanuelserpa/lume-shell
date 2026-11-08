.pragma library

function requestRestart(state, processRunning) {
    if (!processRunning)
        return false
    state.restartPending = true
    return true
}

function requestStart(state) {
    state.startObserved = false
}

function observeStart(state) {
    state.startObserved = true
}

function shouldReportStartFailure(state, processRunning) {
    return !state.restartPending && !state.startObserved && !processRunning
}

function consumeRestart(state) {
    if (!state.restartPending)
        return false
    state.restartPending = false
    return true
}
