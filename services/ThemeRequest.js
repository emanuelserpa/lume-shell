.pragma library

function create() {
    return { pending: "", revision: 0 }
}

function request(state, id) {
    state.pending = id
    state.revision += 1
}

function take(state) {
    const id = state.pending
    state.pending = ""
    return id
}

function isCurrent(state, revision) {
    return state.revision === revision
}
