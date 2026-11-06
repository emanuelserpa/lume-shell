.pragma library

// Resolve session identity only for compositor-specific fallback features.
// Protocol-backed providers are selected from the state they expose instead.
function identifiers(desktop) {
    return String(desktop ?? "").toLowerCase().split(":").filter(Boolean)
}

function kindForDesktop(desktop) {
    const names = identifiers(desktop)
    if (names.includes("hyprland")) return "hyprland"
    if (names.includes("mango")) return "mango"
    if (names.includes("labwc")) return "labwc"
    return "wayland"
}

function hasHyprlandNativeFeatures(desktop) {
    return kindForDesktop(desktop) === "hyprland"
}
