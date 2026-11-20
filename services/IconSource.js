.pragma library

const iconUrlPrefix = "image://icon/"

// System tray/menu models may expose themed icons through Quickshell's
// image://icon provider. Resolve these to files so QtQuick.Image decodes them
// directly instead of asking the QIcon pixmap provider to render them.
function resolve(source, iconPathResolver) {
    const value = String(source ?? "")
    if (!value.startsWith(iconUrlPrefix)) return value
    if (typeof iconPathResolver !== "function") return ""

    let name = value.slice(iconUrlPrefix.length).split("?")[0]
    try {
        name = decodeURIComponent(name)
    } catch (error) {
        return ""
    }
    if (!name || name.startsWith("/")) return ""

    try {
        return String(iconPathResolver(name, true) ?? "")
    } catch (error) {
        return ""
    }
}
