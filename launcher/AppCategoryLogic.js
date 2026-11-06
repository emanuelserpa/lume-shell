.pragma library

var categories = [
    { id: "all", label: "Todos", icon: "󰕱", match: [] },
    { id: "media", label: "Multimídia", icon: "", match: ["AudioVideo", "Audio", "Video", "Player", "Recorder"] },
    { id: "dev", label: "Desenvolvimento", icon: "󰘐", match: ["Development"] },
    { id: "edu", label: "Educação", icon: "", match: ["Education"] },
    { id: "game", label: "Jogos", icon: "󰊴", match: ["Game"] },
    { id: "graphics", label: "Gráficos", icon: "", match: ["Graphics"] },
    { id: "net", label: "Rede", icon: "󰤨", match: ["Network"] },
    { id: "office", label: "Escritório", icon: "", match: ["Office"] },
    { id: "system", label: "Sistema", icon: "󰒓", match: ["System", "Settings", "Administration"] },
    { id: "science", label: "Ciência", icon: "", match: ["Science"] },
    { id: "util", label: "Utilitários", icon: "", match: ["Utility"] },
    { id: "other", label: "Outros", icon: "", match: [] }
]

function entryCategories(entry) {
    try {
        const value = entry?.categories
        if (!value) return []
        if (Array.isArray(value)) return value.map(item => String(item))
        if (typeof value === "string") {
            return value.split(";").map(item => item.trim()).filter(item => item.length > 0)
        }
        if (typeof value.length === "number") {
            const result = []
            for (let index = 0; index < value.length; index++)
                result.push(String(value[index]))
            return result
        }
    } catch (error) {}
    return []
}

function bucketOf(entry) {
    const entryCats = entryCategories(entry)
    for (let index = 1; index < categories.length - 1; index++) {
        const category = categories[index]
        if (category.match.some(value => entryCats.indexOf(value) !== -1))
            return category.id
    }
    return "other"
}

function labelFor(entry) {
    const categoryId = bucketOf(entry)
    const category = categories.find(item => item.id === categoryId)
    return category?.label ?? "Outros"
}

function contextLabel(categoryLabel) {
    const category = String(categoryLabel ?? "").trim()
    return category.length > 0 && category !== "Aplicativo"
        ? "Aplicativo · " + category
        : "Aplicativo"
}

function matchesCategory(entry, categoryId) {
    return categoryId === "all" || bucketOf(entry) === categoryId
}
