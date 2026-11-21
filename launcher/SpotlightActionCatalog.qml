import QtQuick

// Etapa 0 do plano Raycast (docs/spotlight-raycast-plan.md): catálogo puro
// que declara, por kind de resultado, as ações disponíveis com primária
// explícita. Sem execuções, sem acesso a sistema: só dados. O activate()
// existente continua sendo o caminho compatível da ação primária.
QtObject {
    // function actionsFor(item) -> [{ id, title, hint, primary }]
    function actionsFor(item) {
        const kind = String(item?.kind ?? "")
        const clipboardItem = item?.payload ?? item
        if (kind === "clipboard" && String(clipboardItem.clipType ?? "") === "image") {
            return [
                { id: "restore", title: "Restaurar", icon: "󰔎", tablerIcon: "clipboard", hint: "Enter", primary: true, group: "Principal" },
                { id: "open-image", title: "Abrir imagem", icon: "󰋩", tablerIcon: "photo", hint: "Ctrl+Enter", primary: false, group: "Ações" },
                { id: "delete", title: "Excluir", icon: "󰆴", tablerIcon: "dashboard-trash", hint: "Del", primary: false, group: "Gerenciar" }
            ]
        }
        if (kind === "clipboard" && String(clipboardItem.clipboardUrl ?? "").length > 0) {
            return [
                { id: "restore", title: "Restaurar", icon: "󰔎", tablerIcon: "clipboard", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "open-player", title: "Abrir no Aurora MPV", icon: "󰐹", tablerIcon: "bar-play", hint: "", primary: false, group: "Ações" },
                { id: "download-video", title: "Baixar vídeo…", icon: "󰇚", tablerIcon: "dashboard-arrow-down", hint: "", primary: false, group: "Ações" },
                { id: "download-audio", title: "Baixar áudio…", icon: "󰝚", tablerIcon: "bar-music", hint: "", primary: false, group: "Ações" },
                { id: "delete", title: "Excluir", icon: "󰆴", tablerIcon: "dashboard-trash", hint: "Del", primary: false, group: "Gerenciar" }
            ]
        }
        switch (kind) {
        case "app":
            return [
                { id: "open", title: "Abrir", icon: "󰌌", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" },
                { id: "open-new", title: "Nova instância", icon: "󰐥", tablerIcon: "external-link", hint: "", primary: false, group: "Ações" },
                { id: "copy-command", title: "Copiar comando", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "file":
            return [
                { id: "open", title: "Abrir", icon: "󰌌", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-path", title: "Copiar caminho", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "reveal", title: "Abrir pasta", icon: "󰈔", tablerIcon: "bar-folder", hint: "", primary: false, group: "Ações" },
                { id: "terminal", title: "Abrir no terminal", icon: "󰆍", tablerIcon: "bar-terminal", hint: "", primary: false, group: "Ações" }
            ]
        case "window":
            return [
                { id: "focus", title: "Focar", icon: "󰍉", tablerIcon: "search", hint: "Enter", primary: true, group: "Principal" },
                { id: "close", title: "Fechar", icon: "󰅙", tablerIcon: "close", hint: "Ctrl+Enter", primary: false, group: "Gerenciar" }
            ]
        case "clipboard":
            return [
                { id: "restore", title: "Restaurar", icon: "󰔎", tablerIcon: "clipboard", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "delete", title: "Excluir", icon: "󰆴", tablerIcon: "dashboard-trash", hint: "Del", primary: false, group: "Gerenciar" }
            ]
        case "emoji":
            return [
                { id: "insert", title: "Inserir", icon: "󰚌", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "calc":
            return [
                { id: "copy-result", title: "Copiar resultado", icon: "󰅍", tablerIcon: "copy", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-expression", title: "Copiar expressão", icon: "󰅍", tablerIcon: "copy", hint: "", primary: false, group: "Copiar" }
            ]
        case "command":
            return [
                { id: "run", title: "Executar", icon: "󰌌", tablerIcon: "bar-terminal", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-command", title: "Copiar comando", icon: "󰅍", tablerIcon: "copy", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "system":
            return [
                { id: "run", title: "Executar", icon: "󰐥", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" }
            ]
        case "url":
            return [
                { id: "download-video", title: "Baixar vídeo…", icon: "󰇚", tablerIcon: "dashboard-arrow-down", hint: "Enter", primary: true, group: "Principal" },
                { id: "open-player", title: "Abrir no Aurora MPV", icon: "󰐹", tablerIcon: "bar-play", hint: "", primary: false, group: "Ações" },
                { id: "download-audio", title: "Baixar áudio…", icon: "󰝚", tablerIcon: "bar-music", hint: "", primary: false, group: "Ações" }
            ]
        case "download":
            return [
                { id: "reveal-download", title: "Abrir pasta", icon: "󰈔", tablerIcon: "bar-folder", hint: "Enter", primary: true, group: "Principal" },
                { id: "retry-download", title: "Tentar de novo", icon: "󰑓", tablerIcon: "bar-refresh", hint: "", primary: false, group: "Ações" },
                { id: "cancel-download", title: "Cancelar", icon: "󰅙", tablerIcon: "close", hint: "", primary: false, group: "Gerenciar" }
            ]
        case "config_category":
            return [
                { id: "open", title: "Abrir", icon: "󰌌", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" }
            ]
        default:
            return [
                { id: "activate", title: "Executar", icon: "󰌌", tablerIcon: "external-link", hint: "Enter", primary: true, group: "Principal" }
            ]
        }
    }

    function primaryAction(item) {
        const actions = actionsFor(item)
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].primary)
                return actions[i]
        }
        return actions.length > 0 ? actions[0] : null
    }

    function secondaryAction(item) {
        const actions = actionsFor(item)
        for (let i = 0; i < actions.length; i++) {
            if (!actions[i].primary)
                return actions[i]
        }
        return null
    }
}
