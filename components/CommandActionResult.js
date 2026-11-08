.pragma library
.import "../services/CommandResult.js" as CommandResult

function complete(exitCode, stdout, stderr, fallbackError) {
    const decoded = CommandResult.decode(stdout)
    const diagnostic = String(stderr ?? "").trim()
    let error = ""
    if (exitCode !== 0) {
        error = diagnostic || decoded.error
            || (fallbackError + " (código " + exitCode + ")")
    } else if (!decoded.ok) {
        error = diagnostic || decoded.error || fallbackError
    }
    const ok = exitCode === 0 && decoded.ok
    return {
        ok: ok,
        result: ok
            ? decoded
            : ({ok: false, version: decoded.version, data: decoded.data, error: error}),
        error: ok ? "" : String(error || fallbackError)
    }
}
