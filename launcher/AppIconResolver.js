.pragma library

var elecwhatIconPath = "file:///usr/share/icons/hicolor/256x256/apps/elecwhat.png"

function resolve(iconName, themedPath) {
    const resolved = String(themedPath ?? "")
    if (resolved.length > 0)
        return resolved

    return String(iconName ?? "").trim().toLowerCase() === "elecwhat"
            ? elecwhatIconPath
            : ""
}
