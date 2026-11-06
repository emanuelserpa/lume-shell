function formatText(str) {
    if (!str) return ""
    const text = typeof str === "string" ? str : String(str)
    return text
        .replace(/<br\s*[\/]?>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'")
        .replace(/&#39;/g, "'")
        .replace(/&#x27;/g, "'")
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&#(\d+);/g, function(_, decimal) {
            return String.fromCharCode(Number(decimal))
        })
        .replace(/&#x([0-9a-fA-F]+);/g, function(_, hex) {
            return String.fromCharCode(parseInt(hex, 16))
        })
        .trim()
}

function storageSnapshot(notification, receivedAt) {
    const n = notification || {}
    const hints = {}
    const sourceHints = n.hints || {}
    if (sourceHints["image-path"])
        hints["image-path"] = String(sourceHints["image-path"])
    if (sourceHints["image_path"])
        hints["image_path"] = String(sourceHints["image_path"])
    return {
        receivedAt: Number(receivedAt),
        appName: String(n.appName ?? "Notificação").slice(0, 512),
        desktopEntry: String(n.desktopEntry ?? "").slice(0, 512),
        appIcon: String(n.appIcon ?? "").slice(0, 2048),
        image: String(n.image ?? "").slice(0, 4096),
        summary: String(n.summary ?? "").slice(0, 32768),
        body: String(n.body ?? "").slice(0, 32768),
        urgency: Number(n.urgency ?? 1),
        hints: hints
    }
}

function isPlaceholderLabel(value) {
    const text = String(value ?? "").trim().toLowerCase()
    if (text.length === 0) return true
    return [
        "notificação", "notificacao", "notificações", "notificacoes",
        "notification", "notifications", "new notification", "nova notificação",
        "unknown", "desconhecido", "ação", "acao", "action", "actions",
        "null", "undefined", "none", "nenhum", "empty", "vazio"
    ].indexOf(text) !== -1
}

function hasRealImage(notification) {
    if (!notification) return false
    const image = String(notification.image ?? "").trim()
    if (!image || image.startsWith("image://icon/")) return false
    const appIcon = String(notification.appIcon ?? "").trim()
    if (appIcon && image === appIcon) return false
    return image.startsWith("/") || image.startsWith("file://")
}

function hasUsefulAction(actions) {
    if (!actions || actions.length === 0) return false
    for (let i = 0; i < actions.length; i++) {
        const label = String(actions[i]?.text ?? actions[i]?.label ?? "").trim()
        if (label && !isPlaceholderLabel(label)) return true
    }
    return false
}

function hasUsefulContent(notification) {
    if (!notification) return false
    const summary = formatText(notification.summary)
    const body = formatText(notification.body)
    if ((summary && !isPlaceholderLabel(summary)) || (body && !isPlaceholderLabel(body)))
        return true
    if (hasRealImage(notification)) return true
    return hasUsefulAction(notification.actions)
}

function isBattery(n) {
    if (!n) return false
    const iconName = String(n.appIcon ?? "").toLowerCase()
    if (iconName.indexOf("battery") !== -1) return true
    const app = String(n.appName ?? "").toLowerCase()
    if (app === "battery" || app === "bateria" || app === "upower") return true
    const hay = (String(n.appName ?? "") + "\n"
        + formatText(n.summary) + "\n"
        + formatText(n.body)).toLowerCase()
    return hay.indexOf("bateria") !== -1 || hay.indexOf("battery") !== -1
}

function isNetworkApplet(n) {
    if (!n) return false
    const desktop = String(n.desktopEntry || n.hints?.["desktop-entry"] || "").trim().toLowerCase()
    if (desktop === "nm-applet"
            || desktop === "nm-applet.desktop"
            || desktop === "org.freedesktop.network-manager-applet"
            || desktop === "org.freedesktop.network-manager-applet.desktop")
        return true
    const app = String(n.appName ?? "").trim().toLowerCase()
    return app === "nm-applet"
        || app === "networkmanager applet"
        || app === "miniaplicativo gerenciador de redes"
        || app === "miniaplicativo networkmanager"
}

function isExcludedFromHistory(n) {
    return isBattery(n) || isNetworkApplet(n)
}

function isChargingNotification(n) {
    if (!n) return false
    const hay = (String(n.appName ?? "") + " "
        + String(n.appIcon ?? "") + " "
        + formatText(n.summary) + " "
        + formatText(n.body)).toLowerCase()
    if (hay.indexOf("conectar") !== -1 || hay.indexOf("fraca") !== -1 || hay.indexOf("low") !== -1 || hay.indexOf("crit") !== -1 || hay.indexOf("caution") !== -1)
        return false
    return hay.indexOf("carregador conectado") !== -1 || hay.indexOf("charging") !== -1 || hay.indexOf("carregando") !== -1 || hay.indexOf("plugged") !== -1
}

function isBatteryAlert(n) {
    return isBattery(n) && !isChargingNotification(n)
}

function isCriticalNotification(n) {
    if (!n) return false
    const urgency = Number(n.urgency ?? 1)
    if (urgency === 2) return true
    const hay = (String(n.appName ?? "") + " "
        + String(n.appIcon ?? "") + " "
        + formatText(n.summary) + " "
        + formatText(n.body)).toLowerCase()
    return hay.indexOf("critica") !== -1 || hay.indexOf("crítica") !== -1
        || hay.indexOf("critic") !== -1 || hay.indexOf("very-low") !== -1
        || hay.indexOf("5%") !== -1 || hay.indexOf("battery-empty") !== -1
}

function visibleToastItems(toasts, fullscreen, criticalUrgency) {
    if (!fullscreen) return toasts
    return toasts.filter(function(toast) {
        return toast?.notification?.urgency === criticalUrgency
    })
}

function withoutBatteryAlertToasts(toasts) {
    return (toasts ?? []).filter(function(toast) {
        return !isBatteryAlert(toast?.notification)
    })
}

function batteryIcon(n) {
    if (!n) return "󰁹"
    if (isChargingNotification(n)) {
        return "󰂄"
    }
    if (isCriticalNotification(n)) {
        return "󰂃"
    }
    const hay = (String(n.appName ?? "") + " "
        + String(n.appIcon ?? "") + " "
        + formatText(n.summary) + " "
        + formatText(n.body)).toLowerCase()
    if (hay.indexOf("fraca") !== -1 || hay.indexOf("low") !== -1 || hay.indexOf("caution") !== -1 || hay.indexOf("10%") !== -1 || hay.indexOf("15%") !== -1 || hay.indexOf("20%") !== -1 || hay.indexOf("conectar") !== -1) {
        return "󰁺"
    }
    return "󰁾"
}

function notificationGroupKey(notification) {
    if (!notification) return ""
    const desktop = String(notification.desktopEntry || "").trim()
    const name = String(notification.appName || "").trim()
    return desktop ? "desktop:" + desktop : (name ? "name:" + name : "id:" + notification.id)
}

// Input is newest-first. Keep QObject references so actions/dismissal stay native.
function historyRows(notifications, expandedKeys) {
    const groups = []
    const byKey = Object.create(null)
    for (const n of notifications || []) {
        if (!n || isExcludedFromHistory(n)) continue
        const name = String(n.appName || "").trim()
        // Android-style shade: one collapsible group per app, including all
        // chat conversations and personal chats emitted by that app.
        const key = notificationGroupKey(n)
        if (!byKey[key]) {
            byKey[key] = {
                key: key,
                name: name || "Notificação",
                items: []
            }
            groups.push(byKey[key])
        }
        byKey[key].items.push(n)
    }
    const rows = []
    for (const group of groups) {
        const expanded = (expandedKeys || []).indexOf(group.key) !== -1
        const items = expanded ? group.items : group.items.slice(0, 1)
        for (let i = 0; i < items.length; i++) {
            rows.push({ notification: items[i], key: group.key,
                        name: group.name,
                        count: group.items.length, header: i === 0 && group.items.length > 1,
                        expanded: expanded, first: i === 0, last: i === items.length - 1 })
        }
    }
    return rows
}
