const _MAX_META_CACHE = 1500
const _metaCache = new Map()

function formatText(str) {
    if (!str) return ""
    const text = typeof str === "string" ? str : String(str)
    const hasTag = text.indexOf("<") !== -1
    const hasEntity = text.indexOf("&") !== -1
    if (!hasTag && !hasEntity)
        return text.trim()

    let result = text
    if (hasTag) {
        result = result
            .replace(/<br\s*[\/]?>/gi, '\n')
            .replace(/<[^>]+>/g, '')
    }
    if (hasEntity) {
        result = result
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
    }
    return result.trim()
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

function _computeStaticMetadata(n, appNameRaw, appIconRaw, imageRaw, summaryRaw, bodyRaw) {
    const summary = formatText(summaryRaw)
    const body = formatText(bodyRaw)
    const appTrimmed = String(appNameRaw ?? "").trim()
    const iconLower = String(appIconRaw ?? "").toLowerCase()
    const appLower = appTrimmed.toLowerCase()
    const textOrImageUseful = Boolean(
        (summary && !isPlaceholderLabel(summary))
        || (body && !isPlaceholderLabel(body))
        || hasRealImage(n)
    )
    let battery = false
    if (iconLower.indexOf("battery") !== -1
            || appLower === "battery" || appLower === "bateria" || appLower === "upower") {
        battery = true
    } else {
        const hay = (String(appNameRaw ?? "") + "\n" + summary + "\n" + body).toLowerCase()
        battery = hay.indexOf("bateria") !== -1 || hay.indexOf("battery") !== -1
    }
    const baseFingerprint = appTrimmed + "\n" + summary + "\n" + body + "\n"
    return {
        appName: appNameRaw,
        appIcon: appIconRaw,
        image: imageRaw,
        summary: summaryRaw,
        body: bodyRaw,
        summaryFormatted: summary,
        bodyFormatted: body,
        textOrImageUseful: textOrImageUseful,
        battery: battery,
        excluded: battery,
        baseFingerprint: baseFingerprint
    }
}

function trackedMetadata(n) {
    if (!n) {
        return {
            useful: false,
            battery: false,
            excluded: false,
            baseFingerprint: "\n\n\n"
        }
    }
    const appNameRaw = n.appName
    const appIconRaw = n.appIcon
    const imageRaw = n.image
    const summaryRaw = n.summary
    const bodyRaw = n.body
    const hasCacheId = n.id !== undefined && n.id !== null && n.id !== ""
    const cacheKey = hasCacheId
        ? ((n.archived ? "a:" : "l:") + String(n.id))
        : ""
    let entry = hasCacheId ? _metaCache.get(cacheKey) : null
    if (!entry
            || entry.appName !== appNameRaw
            || entry.appIcon !== appIconRaw
            || entry.image !== imageRaw
            || entry.summary !== summaryRaw
            || entry.body !== bodyRaw) {
        entry = _computeStaticMetadata(n, appNameRaw, appIconRaw, imageRaw, summaryRaw, bodyRaw)
        if (hasCacheId) {
            if (_metaCache.size >= _MAX_META_CACHE)
                _metaCache.delete(_metaCache.keys().next().value)
            _metaCache.set(cacheKey, entry)
        }
    }
    return {
        useful: entry.textOrImageUseful || hasUsefulAction(n.actions),
        battery: entry.battery,
        excluded: entry.excluded,
        baseFingerprint: entry.baseFingerprint
    }
}

function hasUsefulContent(notification) {
    return trackedMetadata(notification).useful
}

function isBattery(n) {
    return trackedMetadata(n).battery
}

function isExcludedFromHistory(n) {
    return trackedMetadata(n).excluded
}

function baseFingerprint(n) {
    return trackedMetadata(n).baseFingerprint
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

function findToastIndexForIncoming(toasts, notification) {
    if (!notification || !Array.isArray(toasts)) return -1
    const key = String(notification.id ?? "")
    const replaceKey = String(notification.replaceKey ?? "")
    for (let i = 0; i < toasts.length; i++) {
        const toast = toasts[i]
        if (!toast) continue
        if (String(toast.id ?? "") === key)
            return i
        if (replaceKey.length > 0 && String(toast.notification?.replaceKey ?? "") === replaceKey)
            return i
    }
    return -1
}

function hasCriticalNotification(trackedList, internalList, criticalUrgency) {
    const lists = [trackedList, internalList]
    for (let l = 0; l < lists.length; l++) {
        const list = lists[l]
        if (!list || list.length === 0) continue
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].urgency === criticalUrgency)
                return true
        }
    }
    return false
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

function capByGroup(notifications, maxPerGroup) {
    const list = notifications || []
    const cap = Number(maxPerGroup)
    if (!cap || cap < 1) return list.slice()
    const counts = Object.create(null)
    const kept = []
    for (let i = 0; i < list.length; i++) {
        const n = list[i]
        if (!n) continue
        const key = notificationGroupKey(n)
        if (key && !key.startsWith("id:")) {
            const count = counts[key] || 0
            if (count >= cap) continue
            counts[key] = count + 1
        }
        kept.push(n)
    }
    return kept
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
