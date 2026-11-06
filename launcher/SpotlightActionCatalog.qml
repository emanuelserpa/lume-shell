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
                { id: "restore", title: "Restaurar", icon: "󰔎", hint: "Enter", primary: true, group: "Principal" },
                { id: "open-image", title: "Abrir imagem", icon: "󰋩", hint: "Ctrl+Enter", primary: false, group: "Ações" }
            ]
        }
        if (kind === "clipboard" && String(clipboardItem.clipboardUrl ?? "").length > 0) {
            return [
                { id: "restore", title: "Restaurar", icon: "󰔎", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "download-video", title: "Baixar vídeo…", icon: "󰇚", hint: "", primary: false, group: "Ações" },
                { id: "download-audio", title: "Baixar áudio…", icon: "󰝚", hint: "", primary: false, group: "Ações" }
            ]
        }
        switch (kind) {
        case "app":
            return [
                { id: "open", title: "Abrir", icon: "󰌌", hint: "Enter", primary: true, group: "Principal" },
                { id: "open-new", title: "Nova instância", icon: "󰐥", hint: "", primary: false, group: "Ações" },
                { id: "copy-command", title: "Copiar comando", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "file":
            return [
                { id: "open", title: "Abrir", icon: "󰌌", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-path", title: "Copiar caminho", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "reveal", title: "Abrir pasta", icon: "󰈔", hint: "", primary: false, group: "Ações" },
                { id: "terminal", title: "Abrir no terminal", icon: "󰆍", hint: "", primary: false, group: "Ações" }
            ]
        case "window":
            return [
                { id: "focus", title: "Focar", icon: "󰍉", hint: "Enter", primary: true, group: "Principal" },
                { id: "close", title: "Fechar", icon: "󰅙", hint: "Ctrl+Enter", primary: false, group: "Gerenciar" }
            ]
        case "clipboard":
            return [
                { id: "restore", title: "Restaurar", icon: "󰔎", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" },
                { id: "delete", title: "Excluir", icon: "󰆴", hint: "", primary: false, group: "Gerenciar" }
            ]
        case "emoji":
            return [
                { id: "insert", title: "Inserir", icon: "󰚌", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy", title: "Copiar", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "calc":
            return [
                { id: "copy-result", title: "Copiar resultado", icon: "󰅍", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-expression", title: "Copiar expressão", icon: "󰅍", hint: "", primary: false, group: "Copiar" }
            ]
        case "command":
            return [
                { id: "run", title: "Executar", icon: "󰌌", hint: "Enter", primary: true, group: "Principal" },
                { id: "copy-command", title: "Copiar comando", icon: "󰅍", hint: "Ctrl+Enter", primary: false, group: "Copiar" }
            ]
        case "system":
            return [
                { id: "run", title: "Executar", icon: "󰐥", hint: "Enter", primary: true, group: "Principal" }
            ]
        case "url":
            return [
                { id: "download-video", title: "Baixar vídeo…", icon: "󰇚", hint: "Enter", primary: true, group: "Principal" },
                { id: "download-audio", title: "Baixar áudio…", icon: "󰝚", hint: "", primary: false, group: "Ações" }
            ]
        case "download":
            return [
                { id: "reveal-download", title: "Abrir pasta", icon: "󰈔", hint: "Enter", primary: true, group: "Principal" },
                { id: "retry-download", title: "Tentar de novo", icon: "󰑓", hint: "", primary: false, group: "Ações" },
                { id: "cancel-download", title: "Cancelar", icon: "󰅙", hint: "", primary: false, group: "Gerenciar" }
            ]
        default:
            return [
                { id: "activate", title: "Executar", icon: "󰌌", hint: "Enter", primary: true, group: "Principal" }
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
