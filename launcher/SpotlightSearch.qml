import QtQuick
import "AppCategoryLogic.js" as AppCategoryLogic

// Etapa 2 do fatiamento do Spotlight: lógica pura de busca e pontuação.
// Sem estado próprio e sem processos: recebe (itens, consulta, uso) e
// devolve itens de resultado. O Spotlight continua dono da consulta,
// do índice selecionado e da lista exibida.
QtObject {
    id: root

    function normalize(value) {
        return String(value ?? "").toLowerCase().trim()
    }

    function fuzzySubsequenceScore(haystack, needle) {
        const h = root.normalize(haystack)
        const n = root.normalize(needle)
        if (n.length === 0)
            return 0

        let pos = 0
        let streak = 0
        let score = 0

        for (let i = 0; i < h.length && pos < n.length; i++) {
            if (h[i] === n[pos]) {
                streak++
                score += 6 + streak * 3
                pos++
            } else {
                streak = 0
            }
        }

        return pos === n.length ? score : 0
    }

    function execBasename(entry) {
        const raw = String(entry?.execString ?? entry?.exec ?? "").trim()
        if (!raw)
            return ""
        const parts = raw.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) ?? []
        const tokens = []
        for (let token of parts) {
            const t = String(token ?? "").trim().replace(/^["']|["']$/g, "")
            if (!t || t === "env")
                continue
            if (t.startsWith("-") && !t.startsWith("--command="))
                continue
            if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(t))
                continue
            tokens.push(t)
        }
        if (tokens.length === 0)
            return ""
        // Flatpak/snap wrappers launch through "flatpak run <app-id>":
        // match the app id components and --command instead of "flatpak".
        const wrap = tokens[0].split("/").pop()
        if ((wrap === "flatpak" || wrap === "snap") && tokens[1] === "run") {
            const found = []
            for (let i = 2; i < tokens.length; i++) {
                const t = tokens[i]
                if (t.startsWith("--command=")) {
                    const c = t.slice(10).split("/").pop()
                    if (c) found.push(c)
                } else if (/^[A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+/.test(t) && t.indexOf("=") === -1) {
                    found.push(t.split(".").join(" "))
                }
            }
            if (found.length > 0)
                return found.join(" ").replace(/%[a-zA-Z]/g, "")
        }
        return tokens[0].split("/").pop().replace(/%[a-zA-Z]/g, "")
    }

    function scoreEntry(entry, q, usage) {
        const needle = root.normalize(q)
        const useCount = Number((usage ?? {})[String(entry.name ?? "")] ?? 0)
        if (needle.length === 0)
            return useCount * 120

        const name = root.normalize(entry.name)
        const generic = root.normalize(entry.genericName)
        const comment = root.normalize(entry.comment)
        const keywords = root.normalize((entry.keywords ?? []).join(" "))
        const categories = root.normalize((entry.categories ?? []).join(" "))
        const exec = root.normalize(execBasename(entry))

        let score = 0

        if (name === needle) score += 1000
        if (name.startsWith(needle)) score += 600
        else if (name.includes(needle)) score += 320

        if (exec === needle) score += 800
        else if (exec.startsWith(needle)) score += 450
        else if (exec.includes(needle)) score += 240

        if (generic.startsWith(needle)) score += 150
        else if (generic.includes(needle)) score += 90

        if (keywords.includes(needle)) score += 70
        if (categories.includes(needle)) score += 35
        if (comment.includes(needle)) score += 25

        score += root.fuzzySubsequenceScore(name, needle)
        score += root.fuzzySubsequenceScore(exec, needle) * 0.8
        score += root.fuzzySubsequenceScore(generic, needle) * 0.45

        const words = needle.split(/\s+/).filter(x => x.length > 0)
        for (let i = 0; i < words.length; i++) {
            const word = words[i]
            if (name.startsWith(word)) score += 120
            else if (name.includes(word)) score += 60
            if (exec.startsWith(word)) score += 90
            else if (exec.includes(word)) score += 45
            if (keywords.includes(word)) score += 25
            score += root.fuzzySubsequenceScore(name, word) * 0.35
        }

        // Usage influences close matches but never overwhelms a strong textual match.
        score += Math.min(12, useCount) * 18

        return score
    }

    function calculate(expr) {
        const value = String(expr ?? "").trim()

        if (value.length === 0)
            return null

        // Deliberately limited to arithmetic characters.
        if (!/^[0-9+\-*/().%\s]+$/.test(value))
            return null

        try {
            const result = Function('"use strict"; return (' + value + ')')()
            if (typeof result !== "number" || !isFinite(result))
                return null
            return result
        } catch (e) {
            return null
        }
    }

    function appSubtitle(entry) {
        const generic = String(entry?.genericName ?? "").trim()
        if (generic.length > 0)
            return generic

        const comment = String(entry?.comment ?? "").trim()
        if (comment.length > 0)
            return comment

        return ""
    }

    function searchApps(entries, query, usage) {
        const trimmed = String(query ?? "").trim()
        const all = (entries ?? []).filter(entry => entry && entry.name)

        if (trimmed.length === 0) {
            return all
                .map(entry => ({
                    entry: entry,
                    usage: Number((usage ?? {})[String(entry.name ?? "")] ?? 0)
                }))
                .sort((a, b) => {
                    if (b.usage !== a.usage)
                        return b.usage - a.usage
                    return String(a.entry.name).localeCompare(String(b.entry.name))
                })
                .slice(0, 7)
                .map(item => ({
                    kind: "app",
                    title: item.entry.name,
                    subtitle: [
                        root.appSubtitle(item.entry),
                        item.usage > 0 ? "usado " + item.usage + "×" : ""
                    ].filter(value => value.length > 0).join(" · "),
                    icon: item.entry.icon,
                    entry: item.entry,
                    score: item.usage,
                    category: AppCategoryLogic.labelFor(item.entry),
                    section: "Aplicativo"
                }))
        }

        return all
            .map(entry => ({
                entry: entry,
                score: root.scoreEntry(entry, trimmed, usage)
            }))
            .filter(item => item.score > 0)
            .sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score
                return String(a.entry.name).localeCompare(String(b.entry.name))
            })
            .slice(0, 8)
            .map(item => ({
                kind: "app",
                title: item.entry.name,
                subtitle: root.appSubtitle(item.entry),
                icon: item.entry.icon,
                entry: item.entry,
                score: item.score,
                category: AppCategoryLogic.labelFor(item.entry),
                section: "Aplicativo"
            }))
    }

    function filterKill(items, query) {
        const q = root.normalize(query)

        const values = (items ?? [])
            .filter(item =>
                q.length === 0
                || root.normalize(item.title).includes(q)
                || root.normalize(item.class).includes(q)
                || String(item.pid).includes(q)
            )
            .slice(0, 8)

        if (values.length === 0) {
            return [{
                kind: "hint",
                title: "Nenhuma janela",
                subtitle: "Nenhuma janela correspondente",
                icon: "󰅖"
            }]
        }

        return values.map(item => ({
            kind: item.handle ? "close_window" : "kill",
            title: item.title,
            subtitle: item.handle ? item.class + " · Fechar janela" : item.class + " · PID " + item.pid,
            icon: "󰅖",
            pid: item.pid,
            handle: item.handle
        }))
    }

    function filterWindows(items, query) {
        const q = root.normalize(query)

        const values = (items ?? [])
            .filter(item =>
                q.length === 0
                || root.normalize(item.title).includes(q)
                || root.normalize(item.class).includes(q)
                || root.normalize(item.workspaceName).includes(q)
                || String(item.pid).includes(q)
            )
            .slice(0, 8)

        if (values.length === 0) {
            return [{
                kind: "hint",
                title: "Nenhuma janela",
                subtitle: "Nenhuma janela correspondente aberta",
                icon: "󰖯"
            }]
        }

        return values.map(item => ({
            kind: "window",
            title: item.title,
            subtitle: item.class + (item.workspaceName ? " · Workspace " + item.workspaceName : "")
                      + (item.pid ? " · PID " + item.pid : ""),
            icon: item.class,
            address: item.address,
            handle: item.handle,
            workspaceId: item.workspaceId,
            workspaceName: item.workspaceName
        }))
    }

    function calcResult(expression) {
        const expr = String(expression ?? "").trim()
        const result = root.calculate(expr)

        if (expr.length === 0) {
            return [{
                kind: "hint",
                title: "Calculadora",
                subtitle: "Digite uma expressão, por exemplo: = 125 * 1.18",
                icon: "󰪚"
            }]
        }

        if (result === null) {
            return [{
                kind: "hint",
                title: "Expressão inválida",
                subtitle: "Use números e operadores + − × ÷ % ( )",
                icon: "󰅙"
            }]
        }

        return [{
            kind: "calc",
            title: String(result),
            subtitle: expr + " · ↵ copiar para a área de transferência",
            icon: "󰪚",
            value: String(result),
            expression: expr
        }]
    }

    function commandResult(command) {
        const cmd = String(command ?? "").trim()

        return [{
            kind: cmd.length > 0 ? "command" : "hint",
            title: cmd.length > 0 ? cmd : "Executar comando",
            subtitle: cmd.length > 0
                      ? "Executar no shell"
                      : "Digite depois de >",
            icon: "",
            command: cmd
        }]
    }
}
