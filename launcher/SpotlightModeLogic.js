.pragma library

var actionRoutes = [
    {id: "themes", prefixes: [":tema", ":theme", ":config"], title: "Temas", sources: ["themeActions"]},
    {id: "display-energy", prefixes: [":tela"], title: "Tela & Energia", sources: ["nightlightActions", "energyActions"]},
    {id: "nightlight", prefixes: [":luz", ":night", ":display"], title: "Luz Noturna", sources: ["nightlightActions"]},
    {id: "energy", prefixes: [":energia", ":power", ":bateria"], title: "Energia", sources: ["energyActions"]},
    {id: "capture", prefixes: [":captura", ":capture", ":qr"], title: "Captura e compartilhamento", sources: ["captureActions"]},
    {id: "connections", prefixes: [":conexoes", ":conex", ":rede", ":net"], title: "Conexões", sources: ["connectionActions"]},
    {id: "system", prefixes: [":sistema", ":system"], title: "Sistema & Sessão", sources: ["systemActionsList", "sessionActions"]},
    {id: "session", prefixes: [":sessao", ":session"], title: "Sessão", sources: ["sessionActions"]}
]

function actionRoute(query) {
    const value = String(query ?? "").trim().toLowerCase()
    for (const route of actionRoutes) {
        for (const prefix of route.prefixes) {
            if (value.startsWith(prefix))
                return {id: route.id, prefix: prefix, title: route.title, sources: route.sources}
        }
    }
    return null
}

function modeForQuery(query) {
    const value = String(query ?? "").trim()
    if (value.startsWith(">")) return "command"
    if (value.startsWith("=")) return "calculation"
    if (value.startsWith("@")) return "files"
    if (value.startsWith("#")) return "clipboard"
    if (value.startsWith(";")) return "emoji"
    if (value.startsWith("!")) return "kill"
    if (value.startsWith("~")) return "windows"
    if (value.startsWith(":"))
        return actionRoute(value)?.id === "themes" ? "themes" : "actions"
    return "universal"
}
