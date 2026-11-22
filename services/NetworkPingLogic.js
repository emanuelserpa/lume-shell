.pragma library

function derivePingPresentation(rawPing, rawStatus, ready, portalDetected) {
    const status = portalDetected ? "portal" : String(rawStatus || "unknown")
    const pingMs = status === "portal" ? -1 : Number(rawPing ?? -1)

    if (Number.isFinite(pingMs) && pingMs >= 0) {
        const tone = pingMs < 60 ? "good" : (pingMs < 150 ? "warn" : "high")
        return {
            status: "online",
            pingMs: Math.round(pingMs),
            label: Math.round(pingMs) + " ms",
            tone: tone
        }
    }

    if (status === "online") {
        return { status: status, pingMs: -1, label: "Online", tone: "good" }
    }
    if (status === "portal") {
        return { status: status, pingMs: -1, label: "Portal", tone: "warn" }
    }
    if (status === "limited") {
        return { status: status, pingMs: -1, label: "Limitada", tone: "warn" }
    }
    if (status === "offline") {
        return { status: status, pingMs: -1, label: "Offline", tone: "error" }
    }
    return {
        status: "unknown",
        pingMs: -1,
        label: ready ? "Indisponível" : "Verificando…",
        tone: "muted"
    }
}
