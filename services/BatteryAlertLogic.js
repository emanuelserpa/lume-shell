.pragma library

function levelForPercentage(percentage) {
    if (percentage <= 5) return "critical"
    if (percentage <= 10) return "very-low"
    if (percentage <= 20) return "low"
    return ""
}

function notificationForLevel(level, percentage) {
    switch (level) {
    case "low":
        return {
            urgency: "normal",
            appIcon: "battery-low",
            summary: "Bateria fraca",
            body: percentage + "% restante. Considere conectar o carregador."
        }
    case "very-low":
        return {
            urgency: "critical",
            appIcon: "battery-caution",
            summary: "Bateria muito fraca",
            body: percentage + "% restante. Conecte o carregador."
        }
    case "critical":
        return {
            urgency: "critical",
            appIcon: "battery-empty",
            summary: "Bateria criticamente baixa",
            body: percentage + "% restante. Conecte o carregador agora."
        }
    default:
        return null
    }
}

function transition(previousLevel, wasCharging, percentage, isDischarging, isPlugged) {
    if (isPlugged) {
        const showConnected = !wasCharging && previousLevel !== ""
        return {
            level: "",
            wasCharging: true,
            notice: showConnected ? {
                urgency: "low",
                appIcon: "battery-good-charging",
                summary: "Carregador conectado",
                body: "Bateria em " + percentage + "%."
            } : null
        }
    }

    if (!isDischarging) {
        return {level: previousLevel, wasCharging: false, notice: null}
    }

    const level = levelForPercentage(percentage)
    if (!level || level === previousLevel) {
        return {level: previousLevel, wasCharging: false, notice: null}
    }

    return {
        level: level,
        wasCharging: false,
        notice: notificationForLevel(level, percentage)
    }
}
