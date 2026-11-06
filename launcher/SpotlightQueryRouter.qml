import QtQuick
import "SpotlightModeLogic.js" as ModeLogic

Item {
    id: root
    width: 0
    height: 0

    property string query: ""
    property var searchLogic
    property var clipboard
    property var modes
    property var actionCatalog
    property var searchController
    property var applicationEntries: []
    property var appUsage: ({})
    property var normalizer
    property var actionRegistry
    property var downloadState

    // Cheap local URL match only: no process runs while typing. Metadata
    // is fetched lazily after the user picks a download action.
    readonly property var urlPattern: /^https?:\/\/[^\s/$.?#].[^\s]*$/i

    function isDownloadableUrl(text) {
        const value = String(text ?? "").trim()
        return value.length > 0 && value.length <= 2048 && root.urlPattern.test(value)
    }

    readonly property var results: normalizer.normalizeAll(
        buildResults(query), undefined, actionRegistry)

    function downloadSubtitle(job) {
        const status = String(job?.status ?? "")
        if (status === "running")
            return "Baixando… · Enter para abrir a pasta"
        if (status === "done")
            return "Concluído · Enter para abrir a pasta"
        if (status === "cancelled")
            return "Cancelado · Enter para tentar de novo"
        return "Falhou · Enter para tentar de novo"
    }

    function getActionModeTitle(rawQuery) {
        return ModeLogic.actionRoute(rawQuery)?.title ?? "Configurações"
    }

    function filterActions(items, rawQuery) {
        const q = root.searchLogic.normalize(rawQuery)
        if (q.length === 0)
            return items

        return items.filter(item =>
            root.searchLogic.normalize(item.title).includes(q)
            || root.searchLogic.normalize(item.subtitle).includes(q)
        )
    }

    function buildResults(rawQuery) {
        const trimmed = String(rawQuery ?? "").trim()

        if (root.isDownloadableUrl(trimmed)) {
            return [{
                kind: "url",
                title: trimmed,
                subtitle: "Link detectado · Enter para verificar",
                icon: "󰇚",
                payload: { url: trimmed }
            }]
        }

        if (trimmed.toLowerCase() === "downloads") {
            const jobs = root.downloadState?.jobs ?? []
            if (jobs.length === 0) {
                return [{
                    kind: "hint",
                    title: "Nenhum download recente",
                    subtitle: "Cole um link de vídeo para começar",
                    icon: "󰇚"
                }]
            }
            return jobs.slice(0, 10).map(job => ({
                kind: "download",
                title: String(job?.title ?? job?.url ?? ""),
                subtitle: downloadSubtitle(job),
                icon: "󰇚",
                payload: {
                    jobId: String(job?.job_id ?? ""),
                    url: String(job?.url ?? ""),
                    mode: String(job?.mode ?? "video"),
                    status: String(job?.status ?? ""),
                    file: String(job?.file ?? ""),
                    dest: String(job?.dest ?? "")
                }
            }))
        }

        if (trimmed.startsWith("@")) {
            const q = trimmed.slice(1).trim()
            if (q.length === 0) {
                return [{
                    kind: "hint",
                    title: "Arquivos",
                    subtitle: "Digite depois de @ para procurar em sua pasta pessoal",
                    icon: "󰈔"
                }]
            }

            return root.modes.fileItems.map(item => ({
                kind: "file",
                title: item.name,
                subtitle: item.parent,
                icon: item.is_dir ? "󰉋" : "󰈔",
                path: item.path
            }))
        }

        if (trimmed.startsWith("#")) {
            const q = root.searchLogic.normalize(trimmed.slice(1))

            if (!root.clipboard.available) {
                return [{
                    kind: "hint",
                    title: "Área de transferência indisponível",
                    subtitle: root.clipboard.error.length > 0 ? root.clipboard.error : "O acesso à área de transferência não está disponível",
                    icon: "󰅇"
                }]
            }

            const values = root.clipboard.items
                .filter(item => q.length === 0
                    || root.searchLogic.normalize(item.preview).includes(q)
                    || root.searchLogic.normalize(item.fullText).includes(q)
                )
                .slice(0, 200)

            if (values.length === 0) {
                return [{
                    kind: "hint",
                    title: !root.clipboard.loaded
                           ? "Carregando área de transferência…"
                           : "Área de transferência vazia",
                    subtitle: !root.clipboard.loaded
                              ? "Carregando o histórico da área de transferência"
                              : "Nenhum item correspondente",
                    icon: "󰅇"
                }]
            }

            return values.map(item => ({
                kind: "clipboard",
                title: item.preview.length > 0 ? item.preview : "(conteúdo sem texto)",
                subtitle: String(item.subtitle ?? "Copiar para a área de transferência")
                          + (!root.clipboard.fresh ? " · atualizando…" : "")
                          + (String(item.type ?? "") === "image" ? " · Enter para restaurar" : ""),
                icon: String(item.icon ?? "󰅇"),
                clipId: item.id,
                clipSignature: String(item.signature ?? ""),
                clipType: String(item.type ?? "text"),
                clipboardUrl: root.isDownloadableUrl(item.fullText) ? String(item.fullText).trim() : "",
                thumbnail: String(root.clipboard.thumbs[String(item.id)] ?? ""),
                mime: String(item.mime ?? ""),
                cached: !root.clipboard.fresh,
                fullText: String(item.fullText ?? item.preview ?? ""),
                lineCount: Number(item.lineCount ?? 1),
                charCount: Number(item.charCount ?? 0)
            }))
        }

        const route = ModeLogic.actionRoute(trimmed)
        if (route) {
            let actions = []
            for (const source of route.sources)
                actions = actions.concat(root.actionCatalog[source]())
            return filterActions(actions, trimmed.slice(route.prefix.length).trim())
        }

        if (trimmed.startsWith(":")) {
            return root.searchController.searchActions(trimmed.slice(1).trim())
        }

        if (trimmed.startsWith(";")) {
            if (!root.modes.emojiAvailable) {
                return [{
                    kind: "hint",
                    title: "Base de emojis indisponível",
                    subtitle: "Arquivo de dados não encontrado",
                    icon: "󰞅"
                }]
            }

            const values = root.modes.emojiItems.slice(0, 40)

            if (values.length === 0) {
                return [{
                    kind: "hint",
                    title: "Nenhum emoji",
                    subtitle: "Tente outro termo (ex: fogo, joinha, coração, rindo)",
                    icon: "󰞅"
                }]
            }

            return values.map(item => ({
                kind: "emoji",
                title: item.char + "  " + (item.name ?? item.description ?? ""),
                subtitle: "Inserir emoji · ↵ selecionar",
                icon: item.char,
                emoji: item.char
            }))
        }

        if (trimmed.startsWith("!")) {
            return root.searchController.searchCloseWindows(trimmed.slice(1), root.modes.killItems)
        }

        if (trimmed.startsWith("~")) {
            return root.searchController.searchWindows(trimmed.slice(1), root.modes.windowItems)
        }

        if (trimmed.startsWith("=")) {
            return root.searchLogic.calcResult(trimmed.slice(1))
        }

        if (trimmed.startsWith(">")) {
            return root.searchController.searchShell(trimmed.slice(1))
        }

        return root.searchController.searchUniversal(trimmed, root.applicationEntries,
                                                root.appUsage, root.modes.windowItems)
    }

}
