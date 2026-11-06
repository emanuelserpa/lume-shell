pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.controlcenter
import qs.services
import "../services/CommandResult.js" as CommandResult
import "GalleryNav.js" as GalleryNav

Item {
    id: root

    signal folderPickerRequested()
    signal folderPickerFinished()
    signal wallpaperSelectionRequested()

    required property var themeColors
    property var selectedItem: null
    property bool active: false
    property string filterText: ""
    property string kbZone: "gallery"
    property int catIndex: -1
    readonly property var themeFamilies: [
        { id: "catppuccin", name: "Catppuccin", variants: ["catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha"], labels: ["Latte", "Frappé", "Macchiato", "Mocha"], defaultId: "catppuccin-mocha", accent: ThemeState.palettes["catppuccin-mocha"].accent },
        { id: "rose-pine", name: "Rosé Pine", variants: ["rose-pine", "rose-pine-moon", "rose-pine-dawn"], labels: ["Main", "Moon", "Dawn"], defaultId: "rose-pine", accent: ThemeState.palettes["rose-pine"].accent },
        { id: "dracula", name: "Dracula", variants: ["dracula", "dracula-pro", "dracula-pro-blade", "dracula-pro-van-helsing"], labels: ["Classic", "Pro", "Blade", "Van Helsing"], defaultId: "dracula", accent: ThemeState.palettes["dracula"].accent }
    ]
    property var wallpaperColors: []
    property string colorWallpaper: ""
    property string selectedSourceColor: "auto"
    property string previewVariant: "chameleon"
    property var previewTheme: null
    property bool colorBusy: false
    property bool previewPending: false
    property bool colorMode: false
    property int colorIndex: 0
    property int colorActionIndex: 0
    property int appearanceVariantIndex: 0
    property string studioSection: "wallpaper"
    property string pendingColorListPath: ""
    property string pendingApplyColorPath: ""
    property string pendingApplyColorValue: ""
    readonly property bool isChameleonActive: ThemeState.currentTheme.startsWith("chameleon")
    readonly property var stagePalette: (root.isChameleonActive && root.previewTheme?.colors)
                                        ? root.previewTheme.colors
                                        : null
    readonly property color stageAccent: root.stagePalette?.accent ?? root.stagePalette?.primary ?? root.cAccent
    readonly property color stageForeground: root.stagePalette?.foreground ?? root.cForeground
    readonly property color stageSurface: root.themeColors.withAlpha(
        Qt.color(root.stagePalette?.backgroundOpaque ?? root.themeColors.backgroundOpaque),
        root.themeColors.backgroundAlpha
    )
    readonly property color stageGreen: root.stagePalette?.green ?? root.themeColors.green
    readonly property real preferredHeight: studioColumn.implicitHeight + 24

    function paletteForEntry(entry) {
        if (!entry)
            return ThemeState.currentPalette
        if (entry.catalogKind === "family") {
            const activeInFamily = entry.variants.indexOf(ThemeState.currentTheme) >= 0
                                   ? ThemeState.currentTheme
                                   : entry.defaultId
            return ThemeState.palettes[activeInFamily] ?? ThemeState.currentPalette
        }
        if (entry.id === "chameleon") {
            if (root.previewTheme?.colors)
                return root.previewTheme.colors
            const activeChameleon = ThemeState.currentTheme.startsWith("chameleon")
                                    ? ThemeState.currentTheme
                                    : "chameleon"
            return ThemeState.palettes[activeChameleon] ?? ThemeState.currentPalette
        }
        return ThemeState.palettes[entry.id] ?? ThemeState.currentPalette
    }

    function subtitleForEntry(entry) {
        if (!entry)
            return ""
        if (entry.id === "chameleon")
            return "Dinâmico · Wallpaper"
        if (entry.catalogKind === "family")
            return entry.variants.length + " estilos"
        return entry.category === "light" ? "Claro" : "Escuro"
    }

    function activeWallpaperPath() {
        const item = root.wallpaperItems.find(function(w) { return w.current })
        return item ? String(item.path ?? "") : ""
    }

    function targetWallpaperPath() {
        const previewed = String(root.selectedWallpaper?.path ?? "")
        if (previewed.length > 0)
            return previewed
        return root.activeWallpaperPath()
    }

    function refreshWallpaperColors(explicitPath) {
        const path = String(explicitPath ?? root.targetWallpaperPath())
        root.previewVariant = ThemeState.currentTheme.startsWith("chameleon")
                ? ThemeState.currentTheme : "chameleon"
        if (!path) {
            root.wallpaperColors = []
            root.colorWallpaper = ""
            root.previewTheme = null
            root.colorBusy = false
            return
        }
        if (colorListProc.running) {
            root.pendingColorListPath = path
            return
        }
        root.pendingColorListPath = ""
        root.colorBusy = true
        colorListProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "wallpaper-colors", path]
        colorListProc.running = true
    }

    function requestColorPreview() {
        if (!root.colorWallpaper || !root.isChameleonActive)
            return
        if (colorPreviewProc.running) {
            root.previewPending = true
            return
        }
        root.colorBusy = true
        colorPreviewProc.requestPath = root.colorWallpaper
        colorPreviewProc.requestColor = root.selectedSourceColor
        colorPreviewProc.requestVariant = root.previewVariant
        colorPreviewProc.command = [
            "python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py",
            "preview-wallpaper-color", root.colorWallpaper,
            root.selectedSourceColor, root.previewVariant
        ]
        colorPreviewProc.running = true
    }

    function applyChameleonChoice(sourceColor, variantId) {
        const targetPath = root.targetWallpaperPath()
        const activePath = root.activeWallpaperPath()
        const resolvedColor = String(sourceColor ?? root.selectedSourceColor ?? "auto")
        const resolvedVariant = String(variantId ?? (ThemeState.currentTheme.startsWith("chameleon")
                                                     ? ThemeState.currentTheme
                                                     : "chameleon"))
        root.selectedSourceColor = resolvedColor
        root.previewVariant = resolvedVariant

        // Se o usuário está pré-visualizando outro wallpaper no carrossel, atualiza o preview
        // imediatamente e guarda o tom escolhido para quando o wallpaper for aplicado.
        if (targetPath.length > 0 && targetPath !== activePath) {
            root.pendingApplyColorPath = targetPath
            root.pendingApplyColorValue = resolvedColor
            if (resolvedVariant !== ThemeState.currentTheme)
                ThemeState.setTheme(resolvedVariant)
            root.requestColorPreview()
            return
        }

        if (!activePath) {
            ThemeState.setTheme(resolvedVariant)
            return
        }
        if (colorApplyProc.running)
            return
        root.colorBusy = true
        colorApplyProc.command = [
            "python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py",
            "set-wallpaper-color", activePath, resolvedColor, resolvedVariant
        ]
        colorApplyProc.running = true
        root.requestColorPreview()
    }

    function cancelColorPreview() {
        root.colorMode = false
        root.previewPending = false
        root.previewTheme = null
    }

    function navigateStudio(section) {
        root.studioSection = section
        if (section === "wallpaper") {
            root.wpSyncIndex()
            root.kbZone = "gallery"
        } else {
            root.kbZone = "catalog"
        }
    }

    function activateStudioPrimary() {
        if (root.kbZone === "gallery") {
            root.wpActivateSelected()
            return
        }
        if (root.kbZone === "variant") {
            const variants = root.appearanceVariants()
            if (variants.length > 0) {
                const chosen = variants[Math.min(Math.max(0, root.appearanceVariantIndex), variants.length - 1)]
                if (root.isChameleonActive)
                    root.applyChameleonChoice(root.selectedSourceColor, chosen.id)
                else
                    ThemeState.setTheme(chosen.id)
            }
            return
        }
        if (root.kbZone === "colors" && root.isChameleonActive) {
            const choice = root.colorIndex === 0
                           ? "auto"
                           : String(root.wallpaperColors[root.colorIndex - 1] ?? "auto")
            root.applyChameleonChoice(choice, root.previewVariant)
            return
        }
        if (!root.catActivateSelected()) {
            root.catIndex = 0
            root.catActivateSelected()
        }
    }

    function activatePaletteControl() {
        if (root.kbZone === "glass") {
            GlassState.setAlpha(0.68)
            return
        }
        root.activateStudioPrimary()
    }

    function glassMove(delta) {
        if (root.themeColors.labwcSession)
            return
        GlassState.setAlpha(Math.round((GlassState.alpha + delta * 0.05) * 100) / 100)
        root.kbZone = "glass"
    }

    function colorMove(delta) {
        const n = root.wallpaperColors.length + 1
        if (n < 1)
            return
        root.colorIndex = (root.colorIndex + delta + n) % n
        const chosenColor = root.colorIndex === 0 ? "auto" : String(root.wallpaperColors[root.colorIndex - 1] ?? "auto")
        root.applyChameleonChoice(chosenColor, root.previewVariant)
    }

    function variantMove(delta) {
        const choices = root.appearanceVariants()
        if (choices.length === 0)
            return
        const activeId = ThemeState.currentTheme
        let index = choices.findIndex(function(choice) { return choice.id === activeId })
        if (index < 0)
            index = root.appearanceVariantIndex
        index = (index + delta + choices.length) % choices.length
        root.appearanceVariantIndex = index
        root.kbZone = "variant"
        if (root.isChameleonActive)
            root.applyChameleonChoice(root.selectedSourceColor, choices[index].id)
        else
            ThemeState.setTheme(choices[index].id)
    }

    function appearanceVariants() {
        const current = ThemeState.currentTheme
        if (current.startsWith("chameleon"))
            return [
                { id: "chameleon", label: "Escuro" },
                { id: "chameleon-light", label: "Claro" },
                { id: "chameleon-oled", label: "OLED" }
            ]
        const family = root.appearanceFamily()
        if (!family)
            return []
        return family.variants.map(function(id, index) { return { id: id, label: family.labels[index] } })
    }

    function appearanceFamily() {
        if (ThemeState.currentTheme.startsWith("chameleon"))
            return null
        return root.themeFamilies.find(function(f) {
            return f.variants.length > 1 && f.variants.indexOf(ThemeState.currentTheme) >= 0
        }) ?? null
    }

    function colorActionMove(delta) {
        root.colorMove(delta)
    }

    Process {
        id: colorListProc
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                root.colorBusy = false
                if (response.ok) {
                    const data = response.data
                    root.colorWallpaper = String(data.wallpaper ?? "")
                    root.wallpaperColors = data.colors ?? []
                    if (root.pendingApplyColorPath === root.colorWallpaper && root.pendingApplyColorValue.length > 0) {
                        root.selectedSourceColor = root.pendingApplyColorValue
                    } else {
                        root.selectedSourceColor = data.selected ?? "auto"
                    }
                    root.colorIndex = root.selectedSourceColor === "auto"
                        ? 0
                        : Math.max(0, root.wallpaperColors.indexOf(root.selectedSourceColor) + 1)
                    if (root.isChameleonActive)
                        root.requestColorPreview()
                } else {
                    WallpaperState.actionError = response.error
                }
                if (root.pendingColorListPath.length > 0 && root.pendingColorListPath !== root.colorWallpaper) {
                    const nextPath = root.pendingColorListPath
                    root.pendingColorListPath = ""
                    Qt.callLater(function() { root.refreshWallpaperColors(nextPath) })
                }
            }
        }
    }

    Process {
        id: colorPreviewProc
        property string requestPath: ""
        property string requestColor: ""
        property string requestVariant: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                const stillCurrent = colorPreviewProc.requestPath === root.colorWallpaper
                        && colorPreviewProc.requestColor === root.selectedSourceColor
                        && colorPreviewProc.requestVariant === root.previewVariant
                if (stillCurrent) {
                    root.colorBusy = false
                    if (response.ok)
                        root.previewTheme = response.data.theme
                    else
                        WallpaperState.actionError = response.error
                }
                if (root.previewPending) {
                    root.previewPending = false
                    Qt.callLater(root.requestColorPreview)
                }
            }
        }
    }

    Process {
        id: colorApplyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                root.colorBusy = false
                if (response.ok)
                    ThemeState.applyCommandResult(this.text, true)
                else
                    WallpaperState.actionError = response.error
            }
        }
    }

    function catEntries() {
        const q = String(root.filterText ?? "").replace(/^:\w*\s*/, "").trim().toLowerCase()
        const themes = (ThemeState.themesList ?? []).filter(function(t) {
            if (t.id === "chameleon-light" || t.id === "chameleon-oled")
                return false
            return true
        })
        const familyIds = []
        root.themeFamilies.forEach(function(f) { familyIds.push.apply(familyIds, f.variants) })
        const singles = themes.filter(function(t) {
            return familyIds.indexOf(t.id) < 0 && (q.length === 0 || String(t.name ?? "").toLowerCase().includes(q))
        })
        const families = root.themeFamilies.filter(function(f) {
            if (q.length === 0 || f.name.toLowerCase().includes(q))
                return true
            return f.variants.some(function(id) {
                const theme = themes.find(function(t) { return t.id === id })
                return theme && theme.name.toLowerCase().includes(q)
            })
        }).map(function(f) {
            return {
                id: "family:" + f.id,
                name: f.name,
                accent: f.accent,
                catalogKind: "family",
                variants: f.variants,
                labels: f.labels,
                defaultId: f.defaultId
            }
        })
        return singles.concat(families)
    }

    function entryContainsTheme(entry, themeId) {
        if (!entry)
            return false
        if (entry.catalogKind === "family")
            return entry.variants.indexOf(themeId) >= 0
        if (entry.id === "chameleon")
            return String(themeId ?? "").startsWith("chameleon")
        return entry.id === themeId
    }

    function activateCatalogEntry(entry) {
        if (!entry)
            return false
        if (entry.catalogKind === "family") {
            if (!root.entryContainsTheme(entry, ThemeState.currentTheme))
                ThemeState.setTheme(entry.defaultId)
            return true
        }
        if (entry.id === "chameleon") {
            const targetVariant = ThemeState.currentTheme.startsWith("chameleon")
                                  ? ThemeState.currentTheme
                                  : "chameleon"
            ThemeState.setTheme(targetVariant)
            Qt.callLater(root.refreshWallpaperColors)
            return true
        }
        ThemeState.setTheme(entry.id)
        return true
    }

    function toggleKbZone(backwards) {
        const hasVariants = root.appearanceVariants().length > 0
        const hasColors = root.isChameleonActive && root.wallpaperColors.length > 0
        const zones = ["catalog", "gallery"]
        if (hasVariants)
            zones.push("variant")
        if (hasColors)
            zones.push("colors")
        if (!root.themeColors.labwcSession)
            zones.push("glass")
        let zoneIndex = zones.indexOf(root.kbZone)
        if (zoneIndex < 0)
            zoneIndex = 0
        root.kbZone = zones[(zoneIndex + (backwards ? zones.length - 1 : 1)) % zones.length]
        root.studioSection = root.kbZone === "gallery" ? "wallpaper" : "themes"
        if (root.kbZone === "catalog" && root.catIndex < 0) {
            const items = root.catEntries()
            const cur = items.findIndex(function(t) { return root.entryContainsTheme(t, ThemeState.currentTheme) })
            root.catIndex = cur >= 0 ? cur : 0
        }
    }

    function catMove(dx, dy) {
        const items = root.catEntries()
        if (items.length === 0)
            return
        let idx = root.catIndex
        if (idx < 0 || idx >= items.length) {
            const cur = items.findIndex(function(t) { return root.entryContainsTheme(t, ThemeState.currentTheme) })
            idx = cur >= 0 ? cur : 0
        } else {
            idx = GalleryNav.gridMove(idx, items.length, 3, dx, dy)
        }
        root.catIndex = idx
        root.kbZone = "catalog"
        root.studioSection = "themes"
        root.catEnsureVisible()
    }

    function catEnsureVisible() {
        if (root.catIndex < 0)
            return
        const rowH = 52 + root.themeColors.spacingTokens.sm
        const y = Math.floor(root.catIndex / 3) * rowH
        if (y < themesFlick.contentY)
            themesFlick.contentY = y
        else if (y + rowH > themesFlick.contentY + themesFlick.height)
            themesFlick.contentY = Math.min(y + rowH - themesFlick.height, themesFlick.contentHeight - themesFlick.height)
    }

    function catActivateSelected() {
        const items = root.catEntries()
        const item = items[root.catIndex]
        return root.activateCatalogEntry(item)
    }

    onFilterTextChanged: {
        root.catIndex = -1
        // Opening the mode writes its prefix into the search field. That empty
        // filter must not steal the initial gallery focus; real filter text
        // intentionally routes navigation to the theme catalog.
        const query = String(root.filterText ?? "").replace(/^:\w*\s*/, "").trim()
        if (query.length > 0) {
            root.kbZone = "catalog"
            root.studioSection = "themes"
        }
    }

    property int wpIndex: -1
    property var previewQueue: []
    property var activePreviewRequest: null

    readonly property var wallpaperItems: WallpaperState.wpItems ?? []
    readonly property var selectedWallpaper: (root.wpIndex >= 0 && root.wpIndex < root.wallpaperItems.length)
                                             ? root.wallpaperItems[root.wpIndex]
                                             : null

    onWpIndexChanged: {
        if (root.active && root.wpIndex >= 0)
            wpColorDebounce.restart()
    }

    Timer {
        id: wpColorDebounce
        interval: 110
        repeat: false
        onTriggered: {
            const path = root.targetWallpaperPath()
            if (path.length > 0 && path !== root.colorWallpaper)
                root.refreshWallpaperColors(path)
        }
    }

    function wpSyncIndex() {
        root.wpIndex = GalleryNav.syncIndex(root.wallpaperItems, function(item) { return item.current })
    }

    function wpMove(d) {
        const items = root.wallpaperItems
        if (items.length === 0)
            return
        root.studioSection = "wallpaper"
        root.wpIndex = GalleryNav.linearMove(root.wpIndex, items.length, d)
        root.kbZone = "gallery"
    }

    function wpCarouselOffset(index) {
        const count = root.wallpaperItems.length
        if (count === 0)
            return 1000
        let offset = index - root.wpIndex
        if (offset > count / 2)
            offset -= count
        else if (offset < -count / 2)
            offset += count
        return offset
    }

    function wpActivateSelected() {
        const items = root.wallpaperItems
        const item = items[root.wpIndex]
        if (!item)
            return false
        if (!item.current)
            root.applyWallpaper(item.path)
        return true
    }

    function helperResponse(text, context, fallbackError) {
        const response = CommandResult.decode(text)
        if (!response.ok) {
            WallpaperState.actionError = response.error ?? fallbackError ?? ""
            console.warn(context + " failed:", WallpaperState.actionError)
        }
        return response
    }

    function requestWallpaperPreview(delegate) {
        const path = String(delegate.wallpaper?.path ?? "")
        if (!delegate.visible || !delegate.needsPreview || !path || delegate.previewSource)
            return
        if (root.activePreviewRequest?.delegate === delegate
                || root.previewQueue.some(request => request.delegate === delegate && request.path === path))
            return
        root.previewQueue = root.previewQueue.concat([{delegate: delegate, path: path}])
        root.runNextWallpaperPreview()
    }

    function runNextWallpaperPreview() {
        if (wallpaperPreviewProc.running)
            return
        while (root.previewQueue.length > 0) {
            const request = root.previewQueue[0]
            root.previewQueue = root.previewQueue.slice(1)
            if (!request.delegate.visible || !request.delegate.needsPreview
                    || String(request.delegate.wallpaper?.path ?? "") !== request.path
                    || request.delegate.previewSource)
                continue
            root.activePreviewRequest = request
            WallpaperState.actionError = ""
            wallpaperPreviewProc.command = [
                "python3", "-B", Quickshell.shellDir + "/scripts/wallpaper-action.py",
                "preview", request.path
            ]
            wallpaperPreviewProc.running = true
            return
        }
    }

    Process {
        id: wallpaperPreviewProc
        stdout: StdioCollector {
            onStreamFinished: {
                const request = root.activePreviewRequest
                const response = root.helperResponse(this.text, "Wallpaper preview helper")
                if (response.ok && response.data.preview && request?.delegate
                        && String(request.delegate.wallpaper?.path ?? "") === request.path) {
                    request.delegate.previewSource = "file://" + encodeURI(String(response.data.preview))
                }
                root.activePreviewRequest = null
                Qt.callLater(root.runNextWallpaperPreview)
            }
        }
    }

    Process {
        id: wpFolderProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.folderPickerFinished()
                root.refreshGallery()
            }
        }
    }

    Timer {
        id: folderPickerDelay
        interval: 150
        repeat: false
        onTriggered: {
            wpFolderProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/wallpaper-action.py", "folder"]
            wpFolderProc.running = true
        }
    }

    function refreshGallery() {
        WallpaperState.refreshGallery()
    }

    function applyWallpaper(path) {
        WallpaperState.applyWallpaper(path)
    }

    Connections {
        target: WallpaperState
        function onGalleryChanged() {
            root.wpSyncIndex()
            const activePath = root.activeWallpaperPath()
            if (root.isChameleonActive && root.pendingApplyColorPath === activePath && root.pendingApplyColorValue.length > 0) {
                const pendingColor = root.pendingApplyColorValue
                root.pendingApplyColorPath = ""
                root.pendingApplyColorValue = ""
                root.applyChameleonChoice(pendingColor, ThemeState.currentTheme)
            } else if (root.targetWallpaperPath() !== root.colorWallpaper) {
                root.refreshWallpaperColors()
            }
        }
    }

    Connections {
        target: ThemeState
        function onCurrentThemeChanged() {
            if (ThemeState.currentTheme.startsWith("chameleon")) {
                root.previewVariant = ThemeState.currentTheme
                if (root.wallpaperColors.length === 0 || root.activeWallpaperPath() !== root.colorWallpaper)
                    root.refreshWallpaperColors()
            }
        }
    }

    onActiveChanged: {
        if (active) {
            // Enter Theme Studio on the wallpaper carousel, with the active
            // wallpaper selected. Spotlight keeps Qt keyboard focus in its
            // search field and routes navigation through this logical zone.
            root.studioSection = "wallpaper"
            root.kbZone = "gallery"
            root.wpSyncIndex()
            Qt.callLater(root.refreshGallery)
            Qt.callLater(root.refreshWallpaperColors)
        }
    }

    readonly property color cForeground: root.themeColors.foreground
    readonly property color cSecondary: root.themeColors.offWhite
    readonly property color cMuted: root.themeColors.textMuted
    readonly property color cAccent: root.themeColors.accent
    readonly property color cCardBg: root.themeColors.glassPanelSurface
    readonly property color cCardHover: root.themeColors.glassHoverSurface
    readonly property color cBorder: root.themeColors.borderSubtle

    visible: root.active

    Flickable {
        id: studioFlick
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        contentWidth: width
        contentHeight: studioColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        WheelKinetic { scrollTarget: studioFlick }

        Column {
            id: studioColumn
            width: parent.width
            spacing: root.themeColors.spacingTokens.md

            // =================================================================
            // 1. HERO STAGE: CARROSSEL INTERATIVO DE WALLPAPER + SHELL OVERLAY
            // =================================================================
            Rectangle {
                id: heroStage
                width: parent.width
                height: 172
                radius: root.themeColors.radiusLg
                color: root.themeColors.glassCardSurface
                border.width: root.kbZone === "gallery" ? 2 : 1
                border.color: root.kbZone === "gallery" ? root.cAccent : root.cBorder
                clip: true

                Item {
                    id: coverFlow
                    anchors.fill: parent
                    anchors.margins: 6

                    Repeater {
                        model: root.wallpaperItems

                        delegate: Rectangle {
                            id: wallpaperDelegate
                            required property var modelData
                            required property int index

                            readonly property int flowOffset: root.wpCarouselOffset(index)
                            readonly property int wallpaperIndex: index
                            readonly property var wallpaper: modelData
                            readonly property bool needsPreview: /\.(webp|avif|jxl)$/i.test(String(wallpaper?.path ?? ""))
                            readonly property real distance: Math.abs(flowOffset)
                            readonly property real cardScale: distance === 0 ? 1.0 : (distance === 1 ? 0.78 : 0.60)
                            readonly property real cardRotation: flowOffset === 0 ? 0 : -flowOffset * 16
                            property string previewSource: ""

                            width: 304
                            height: 156
                            x: coverFlow.width / 2 - width / 2 + flowOffset * 205
                            y: (coverFlow.height - height) / 2 + distance * 3
                            scale: cardScale
                            rotation: cardRotation
                            z: 20 - distance
                            opacity: distance === 0 ? 1.0 : (distance === 1 ? 0.68 : 0.32)
                            visible: Math.abs(flowOffset) <= 2 && wallpaper !== null
                            transformOrigin: Item.Center
                            radius: root.themeColors.radiusMd
                            clip: true
                            color: root.themeColors.surface
                            border.width: wallpaperDelegate.wallpaper?.current ? 2 : (flowOffset === 0 ? 2 : 1)
                            border.color: wallpaperDelegate.wallpaper?.current
                                          ? root.themeColors.green
                                          : (flowOffset === 0 ? root.cAccent : root.cBorder)

                            Behavior on x { enabled: root.themeColors.qmlAnimationsEnabled; NumberAnimation { duration: root.themeColors.motionLayout; easing.type: root.themeColors.motionEasing } }
                            Behavior on y { enabled: root.themeColors.qmlAnimationsEnabled; NumberAnimation { duration: root.themeColors.motionLayout; easing.type: root.themeColors.motionEasing } }
                            Behavior on scale { enabled: root.themeColors.qmlAnimationsEnabled; NumberAnimation { duration: root.themeColors.motionLayout; easing.type: root.themeColors.motionEasing } }
                            Behavior on rotation { enabled: root.themeColors.qmlAnimationsEnabled; NumberAnimation { duration: root.themeColors.motionLayout; easing.type: root.themeColors.motionEasing } }
                            Behavior on opacity { enabled: root.themeColors.qmlAnimationsEnabled; NumberAnimation { duration: root.themeColors.motionStandard; easing.type: root.themeColors.motionEasing } }

                            onVisibleChanged: root.requestWallpaperPreview(wallpaperDelegate)
                            onWallpaperChanged: {
                                previewSource = ""
                                Qt.callLater(function() {
                                    root.requestWallpaperPreview(wallpaperDelegate)
                                })
                            }
                            Component.onCompleted: Qt.callLater(function() {
                                root.requestWallpaperPreview(wallpaperDelegate)
                            })

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 608
                                sourceSize.height: 312
                                source: {
                                    if (!wallpaperDelegate.visible || !wallpaperDelegate.wallpaper?.path)
                                        return ""
                                    if (wallpaperDelegate.needsPreview)
                                        return wallpaperDelegate.previewSource
                                    return "file://" + encodeURI(String(wallpaperDelegate.wallpaper.path))
                                }
                            }

                            // Mini-barra ao vivo do shell sobreposta ao card central
                            Item {
                                visible: wallpaperDelegate.flowOffset === 0
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 8
                                height: 18

                                // Ilha esquerda simulada
                                Rectangle {
                                    anchors.left: parent.left
                                    width: 48
                                    height: 18
                                    radius: 9
                                    color: root.stageSurface
                                    border.width: 1
                                    border.color: root.themeColors.barIslandBorder
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Rectangle { width: 6; height: 6; radius: 3; color: root.stageForeground; opacity: 0.85 }
                                        Rectangle { width: 12; height: 6; radius: 3; color: root.stageAccent }
                                        Rectangle { width: 6; height: 6; radius: 3; color: root.cMuted; opacity: 0.6 }
                                    }
                                }

                                // Ilha central simulada
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 64
                                    height: 18
                                    radius: 9
                                    color: root.stageSurface
                                    border.width: 1
                                    border.color: root.themeColors.barIslandBorder
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Rectangle { width: 14; height: 5; radius: 2.5; color: root.stageForeground; opacity: 0.8 }
                                        Rectangle { width: 22; height: 5; radius: 2.5; color: root.stageAccent }
                                    }
                                }

                                // Ilha direita simulada
                                Rectangle {
                                    anchors.right: parent.right
                                    width: 58
                                    height: 18
                                    radius: 9
                                    color: root.stageSurface
                                    border.width: 1
                                    border.color: root.themeColors.barIslandBorder
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Rectangle { width: 6; height: 6; radius: 3; color: root.stageAccent }
                                        Rectangle { width: 14; height: 6; radius: 3; color: root.stageGreen }
                                        Rectangle { width: 6; height: 6; radius: 3; color: root.stageForeground }
                                    }
                                }
                            }

                            // Pílula inferior do card central (status / ação imediata)
                            Rectangle {
                                visible: wallpaperDelegate.flowOffset === 0
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width - 20, stageCaptionRow.implicitWidth + 18)
                                height: 22
                                radius: 11
                                color: root.themeColors.backgroundOpaque
                                opacity: 0.90
                                border.width: 1
                                border.color: wallpaperDelegate.wallpaper?.current
                                              ? root.themeColors.withAlpha(root.themeColors.green, 0.6)
                                              : root.themeColors.glassBorder

                                Row {
                                    id: stageCaptionRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wallpaperDelegate.wallpaper?.current ? "✓" : "󰸉"
                                        color: wallpaperDelegate.wallpaper?.current ? root.themeColors.green : root.cAccent
                                        font.family: root.themeColors.nerdFontFamily
                                        font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wallpaperDelegate.wallpaper?.current
                                              ? String(wallpaperDelegate.wallpaper?.filename ?? "Wallpaper ativo")
                                              : "Aplicar " + String(wallpaperDelegate.wallpaper?.filename ?? "wallpaper")
                                        color: root.cForeground
                                        font.family: root.themeColors.fontFamily
                                        font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                        font.weight: Font.Medium
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (wallpaperDelegate.wallpaperIndex < 0)
                                        return
                                    root.kbZone = "gallery"
                                    root.studioSection = "wallpaper"
                                    if (root.wpIndex === wallpaperDelegate.wallpaperIndex) {
                                        root.wpActivateSelected()
                                    } else {
                                        root.wpIndex = wallpaperDelegate.wallpaperIndex
                                        root.wallpaperSelectionRequested()
                                    }
                                }
                                onDoubleClicked: {
                                    if (wallpaperDelegate.wallpaperIndex < 0)
                                        return
                                    root.wpIndex = wallpaperDelegate.wallpaperIndex
                                    root.wpActivateSelected()
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 30
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            const delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
                            if (delta !== 0)
                                root.wpMove(delta < 0 ? 1 : -1)
                        }
                    }
                }

                // Controles flutuantes discretos no canto superior direito do Hero Stage
                Row {
                    z: 40
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 6

                    Rectangle {
                        width: folderBtnRow.implicitWidth + 14
                        height: 26
                        radius: 13
                        color: folderHov.hovered ? root.cCardHover : root.themeColors.backgroundOpaque
                        opacity: 0.90
                        border.width: 1
                        border.color: folderHov.hovered ? root.cAccent : root.cBorder

                        Row {
                            id: folderBtnRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰉋"
                                color: root.cAccent
                                font.family: root.themeColors.nerdFontFamily
                                font.pixelSize: root.themeColors.spotlightBodyFontSize
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Pasta"
                                color: root.cSecondary
                                font.family: root.themeColors.fontFamily
                                font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                font.weight: Font.Medium
                            }
                        }
                        HoverHandler { id: folderHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (!wpFolderProc.running && !folderPickerDelay.running) {
                                    root.folderPickerRequested()
                                    folderPickerDelay.start()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: randHov.hovered ? root.cCardHover : root.themeColors.backgroundOpaque
                        opacity: 0.90
                        border.width: 1
                        border.color: randHov.hovered ? root.cAccent : root.cBorder

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.cAccent
                            font.family: root.themeColors.nerdFontFamily
                            font.pixelSize: root.themeColors.spotlightBodyFontSize
                        }
                        HoverHandler { id: randHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: WallpaperState.randomWallpaper()
                        }
                    }
                }
            }

            // =================================================================
            // 2. BARRA ESTILO & TOM (APPLE / GNOME ACCENT & APPEARANCE BAR)
            // =================================================================
            Rectangle {
                id: styleAndToneBar
                width: parent.width
                height: 40
                radius: root.themeColors.radiusMd
                color: root.themeColors.glassCardSurface
                border.width: (root.kbZone === "variant" || root.kbZone === "colors") ? 2 : 1
                border.color: (root.kbZone === "variant" || root.kbZone === "colors") ? root.cAccent : root.cBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: root.themeColors.spacingTokens.md

                    // Esquerda: Segmented Control de Estilo/Variante (ou etiqueta do tema ativo)
                    Row {
                        spacing: root.themeColors.spacingTokens.sm

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.appearanceVariants().length > 0
                                  ? "Estilo"
                                  : (ThemeState.currentPalette?.name ?? ThemeState.currentTheme)
                            color: root.cSecondary
                            font.family: root.themeColors.fontFamily
                            font.pixelSize: root.themeColors.spotlightLabelFontSize
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            visible: root.appearanceVariants().length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: segmentedVariantsRow.implicitWidth + 6
                            height: 28
                            radius: root.themeColors.radiusSm
                            color: root.themeColors.glassPanelSurface
                            border.width: 1
                            border.color: root.cBorder

                            Row {
                                id: segmentedVariantsRow
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: root.appearanceVariants()
                                    delegate: Rectangle {
                                        id: segVariantBtn
                                        required property var modelData
                                        required property int index
                                        readonly property bool selected: ThemeState.currentTheme === modelData.id
                                        width: segVariantText.implicitWidth + 18
                                        height: 22
                                        radius: root.themeColors.radiusXs
                                        color: selected
                                               ? root.themeColors.surfaceSelected
                                               : (segVarHov.hovered ? root.cCardHover : "transparent")

                                        Text {
                                            id: segVariantText
                                            anchors.centerIn: parent
                                            text: segVariantBtn.modelData.label
                                            color: segVariantBtn.selected
                                                   ? root.themeColors.primaryContainerForeground
                                                   : root.cSecondary
                                            font.family: root.themeColors.fontFamily
                                            font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                            font.weight: segVariantBtn.selected ? Font.DemiBold : Font.Medium
                                        }

                                        HoverHandler { id: segVarHov; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                root.appearanceVariantIndex = segVariantBtn.index
                                                root.kbZone = "variant"
                                                if (root.isChameleonActive)
                                                    root.applyChameleonChoice(root.selectedSourceColor, segVariantBtn.modelData.id)
                                                else
                                                    ThemeState.setTheme(segVariantBtn.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Direita: Accent Dots (bolinhas de cor extraídas do wallpaper no Chameleon)
                    Row {
                        visible: root.isChameleonActive
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.colorBusy ? "Aplicando…" : "Tom"
                            color: root.cMuted
                            font.family: root.themeColors.fontFamily
                            font.pixelSize: root.themeColors.spotlightKeycapFontSize
                            font.weight: Font.Medium
                        }

                        Repeater {
                            model: ["auto"].concat(root.wallpaperColors)
                            delegate: Rectangle {
                                id: accentDot
                                required property var modelData
                                required property int index
                                readonly property bool isAuto: index === 0
                                readonly property bool isSelected: root.selectedSourceColor === String(modelData)
                                readonly property bool isFocused: root.kbZone === "colors" && root.colorIndex === index

                                anchors.verticalCenter: parent.verticalCenter
                                width: isAuto ? autoDotText.implicitWidth + 16 : 20
                                height: 20
                                radius: 10
                                color: isAuto ? root.themeColors.surfaceElevated : String(modelData)
                                border.width: isSelected || isFocused ? 2 : 1
                                border.color: isSelected || isFocused ? root.cForeground : root.cBorder
                                scale: dotHov.hovered || isFocused ? 1.12 : 1.0

                                Behavior on scale {
                                    enabled: root.themeColors.qmlAnimationsEnabled
                                    NumberAnimation { duration: root.themeColors.motionFast; easing.type: root.themeColors.motionEasing }
                                }

                                Text {
                                    id: autoDotText
                                    anchors.centerIn: parent
                                    visible: accentDot.isAuto
                                    text: "Auto"
                                    color: root.cForeground
                                    font.family: root.themeColors.fontFamily
                                    font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                    font.weight: accentDot.isSelected ? Font.Bold : Font.Medium
                                }

                                Rectangle {
                                    visible: accentDot.isSelected && !accentDot.isAuto
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: root.cForeground
                                }

                                HoverHandler { id: dotHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    enabled: !colorApplyProc.running
                                    onTapped: {
                                        root.colorIndex = accentDot.index
                                        root.kbZone = "colors"
                                        root.applyChameleonChoice(String(accentDot.modelData), ThemeState.currentTheme)
                                    }
                                }
                            }
                        }
                    }

                    // Quando um tema fixo está ativo, exibe uma amostra limpa das cores da paleta atual
                    Row {
                        visible: !root.isChameleonActive
                        spacing: 5

                        Repeater {
                            model: [
                                root.cAccent,
                                root.themeColors.green,
                                root.themeColors.yellow,
                                root.themeColors.pink,
                                root.themeColors.red
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData
                                border.width: 1
                                border.color: root.themeColors.withAlpha(root.cBorder, 0.5)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 58
                radius: root.themeColors.radiusMd
                color: root.themeColors.glassPanelSurface
                border.width: root.kbZone === "glass" ? 2 : 1
                border.color: root.kbZone === "glass" ? root.cAccent : root.cBorder

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.themeColors.popupInsets.standard
                    anchors.rightMargin: root.themeColors.popupInsets.standard
                    spacing: root.themeColors.spacingTokens.md

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Vidro líquido"
                        color: root.cForeground
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.typeTokens.bodyEmphasis
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Transparente"
                        color: root.cMuted
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.typeTokens.meta
                    }

                    SliderRow {
                        id: glassSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(130, parent.width - 330)
                        height: root.themeColors.softControlHeight
                        theme: root.themeColors
                        showIcon: false
                        showValue: false
                        minimum: 0.35
                        maximum: 0.90
                        value: GlassState.alpha
                        accent: root.cAccent
                        available: !root.themeColors.labwcSession
                        thumbAlwaysVisible: true
                        onValueRequested: function(value) { GlassState.setAlpha(value) }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Opaco"
                        color: root.cMuted
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.typeTokens.meta
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Padrão"
                        color: resetHover.hovered ? root.cAccent : root.cMuted
                        font.family: root.themeColors.fontFamily
                        font.pixelSize: root.themeColors.typeTokens.meta

                        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: GlassState.setAlpha(0.68) }
                    }
                }
            }

            Text {
                visible: root.themeColors.labwcSession || GlassState.error.length > 0
                width: parent.width
                text: GlassState.error.length > 0
                      ? GlassState.error
                      : "O labwc mantém as superfícies mais opacas porque não aplica desfoque."
                color: GlassState.error.length > 0 ? root.themeColors.red : root.cMuted
                font.family: root.themeColors.fontFamily
                font.pixelSize: root.themeColors.typeTokens.meta
                wrapMode: Text.Wrap
            }

            // =================================================================
            // 3. GRADE DE PALETAS COM MINI-SWATCHES CROMÁTICOS REAIS
            // =================================================================
            Flickable {
                id: themesFlick
                width: parent.width
                height: Math.min(220, themesFlow.implicitHeight)
                contentWidth: width
                contentHeight: themesFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelKinetic { scrollTarget: themesFlick }

                Flow {
                    id: themesFlow
                    width: parent.width
                    spacing: root.themeColors.spacingTokens.sm

                    Repeater {
                        model: root.catEntries()

                        delegate: Rectangle {
                            id: paletteCard
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: root.entryContainsTheme(modelData, ThemeState.currentTheme)
                            readonly property bool kbCursor: root.kbZone === "catalog" && index === root.catIndex
                            readonly property var entryPalette: root.paletteForEntry(modelData)

                            width: (themesFlow.width - themesFlow.spacing * 2) / 3
                            height: 52
                            radius: root.themeColors.radiusMd
                            color: (isSelected && root.kbZone === "catalog")
                                ? root.themeColors.withAlpha(root.cAccent, 0.16)
                                : (kbCursor || thHov.hovered ? root.cCardHover : root.themeColors.glassCardSurface)
                            border.width: kbCursor ? 2 : 1
                            border.color: kbCursor
                                ? root.cAccent
                                : root.cBorder

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                // Miniatura cromática real do tema (fundo + 4 pílulas de cor da própria paleta)
                                Rectangle {
                                    width: 44
                                    height: 32
                                    radius: root.themeColors.radiusSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: paletteCard.entryPalette?.backgroundOpaque ?? root.themeColors.backgroundOpaque
                                    border.width: 1
                                    border.color: root.themeColors.withAlpha(root.cForeground, 0.18)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 28
                                            height: 6
                                            radius: 3
                                            color: paletteCard.entryPalette?.surface ?? root.themeColors.surface
                                            Rectangle {
                                                width: 12
                                                height: 6
                                                radius: 3
                                                color: paletteCard.entryPalette?.accent ?? (paletteCard.modelData.accent ?? root.cAccent)
                                            }
                                        }

                                        Row {
                                            spacing: 3
                                            Rectangle {
                                                width: 7; height: 7; radius: 3.5
                                                color: paletteCard.entryPalette?.accent ?? (paletteCard.modelData.accent ?? root.cAccent)
                                            }
                                            Rectangle {
                                                width: 7; height: 7; radius: 3.5
                                                color: paletteCard.entryPalette?.green ?? root.themeColors.green
                                            }
                                            Rectangle {
                                                width: 7; height: 7; radius: 3.5
                                                color: paletteCard.entryPalette?.yellow ?? root.themeColors.yellow
                                            }
                                            Rectangle {
                                                width: 7; height: 7; radius: 3.5
                                                color: paletteCard.entryPalette?.red ?? root.themeColors.red
                                            }
                                        }
                                    }
                                }

                                // Nome + subtítulo do tema
                                Column {
                                    width: Math.max(40, parent.width - (paletteCard.isSelected ? 88 : 70))
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: paletteCard.modelData.displayName ?? paletteCard.modelData.name
                                        color: paletteCard.isSelected ? root.cForeground : root.cSecondary
                                        font.family: root.themeColors.fontFamily
                                        font.pixelSize: root.themeColors.spotlightLabelFontSize
                                        font.weight: paletteCard.isSelected ? Font.Bold : Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.subtitleForEntry(paletteCard.modelData)
                                        color: root.cMuted
                                        font.family: root.themeColors.fontFamily
                                        font.pixelSize: root.themeColors.spotlightKeycapFontSize
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: paletteCard.isSelected
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✓"
                                    color: root.cAccent
                                    font.family: root.themeColors.fontFamily
                                    font.pixelSize: root.themeColors.spotlightBodyFontSize
                                    font.weight: Font.Bold
                                }
                            }

                            HoverHandler { id: thHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    root.kbZone = "catalog"
                                    root.studioSection = "themes"
                                    root.activateCatalogEntry(paletteCard.modelData)
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.catIndex = paletteCard.index
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
