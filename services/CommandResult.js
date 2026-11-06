function normalize(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        return {
            ok: false,
            version: 1,
            data: ({}),
            error: "A resposta do helper não é um objeto JSON."
        }
    }

    const isEnvelope = typeof value.ok === "boolean"
    const ok = isEnvelope ? value.ok : value.status !== "error" && !value.error
    const version = Number.isInteger(Number(value.version)) && Number(value.version) > 0
                    ? Number(value.version)
                    : 1
    const data = value.data && typeof value.data === "object" && !Array.isArray(value.data)
                 ? value.data
                 : value

    return {
        ok: ok,
        version: version,
        data: data,
        error: ok ? null : String(value.error ?? "O helper informou uma falha.")
    }
}

function decode(text) {
    try {
        return normalize(JSON.parse(String(text ?? "").trim()))
    } catch (error) {
        return {
            ok: false,
            version: 1,
            data: ({}),
            error: "Erro ao interpretar resposta JSON: " + String(error)
        }
    }
}
