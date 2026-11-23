.pragma library

const LOW_BATTERY_THRESHOLD = 15
const HYSTERESIS_THRESHOLD = 18

function evaluateBatteryTransition(state, percentage, isDischarging, isPlugged, activeProfile) {
    const next = {
        autoApplied: Boolean(state?.autoApplied),
        manualOverride: Boolean(state?.manualOverride),
        previousProfile: String(state?.previousProfile || "balanced"),
        action: "none",
        targetProfile: ""
    }

    if (isPlugged) {
        next.manualOverride = false
        if (next.autoApplied && activeProfile === "extra-low-power") {
            next.action = "restore"
            next.targetProfile = next.previousProfile !== "extra-low-power"
                ? next.previousProfile : "balanced"
        }
        next.autoApplied = false
        return next
    }

    if (percentage > HYSTERESIS_THRESHOLD) {
        next.manualOverride = false
    }

    if (!isDischarging) {
        return next
    }

    if (percentage <= LOW_BATTERY_THRESHOLD
            && !next.autoApplied
            && !next.manualOverride
            && activeProfile !== "extra-low-power") {
        next.previousProfile = activeProfile && activeProfile !== "extra-low-power"
            ? activeProfile : "balanced"
        next.autoApplied = true
        next.action = "activate"
        next.targetProfile = "extra-low-power"
    }

    return next
}

function noteManualSelection(state, selectedProfile, percentage, isPlugged) {
    const next = {
        autoApplied: false,
        manualOverride: Boolean(state?.manualOverride),
        previousProfile: String(state?.previousProfile || "balanced")
    }
    if (selectedProfile === "extra-low-power") {
        next.manualOverride = false
    } else if (!isPlugged && percentage <= LOW_BATTERY_THRESHOLD) {
        next.manualOverride = true
    }
    return next
}
