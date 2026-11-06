pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.bar
import qs.components
import qs.services
import "AppIconResolver.js" as AppIconResolver
import "../services/CommandResult.js" as CommandResult
import "SpotlightModeLogic.js" as ModeLogic
import "AppCategoryLogic.js" as AppCategoryLogic

// qmllint disable uncreatable-type
// qmllint disable import
PanelWindow {
    // The compositor plugin provides the concrete PanelWindow implementation.
    // qmllint enable uncreatable-type
    id: root

    // labwc only transfers keyboard focus to layer surfaces with explicit
    // exclusive interactivity; PanelWindow.focusable alone is not enough.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: true
    visible: false
    property bool closingAnimation: false
    aboveWindows: true
    // Its imported Quickshell metadata references an internal PostReloadHook
    // type that the installed tooling does not export.
    // qmllint enable import

    Theme { id: palette }

    SessionActionsPopup {
        id: sessionConfirmation
        theme: palette
        target: card
        ownerActive: root.visible
        confirmationOnly: true
        onActionRequested: function(action) {
            root.closeLauncher()
            Quickshell.execDetached([Quickshell.shellDir + "/scripts/session-action.sh", action])
        }
        onVisibleChanged: {
            if (!visible && root.visible)
                searchInput.forceActiveFocus()
        }
    }

    DownloadPanel {
        id: downloadPanel
        theme: palette
        target: card
        ownerActive: root.visible
        onDoneRequested: root.closeLauncher()
        onPanelDismissed: {
            if (root.visible)
                searchInput.forceActiveFocus()
        }
    }
    readonly property color launcherForeground: palette.surfaceForeground
    readonly property color launcherSecondary: palette.surfaceVariantForeground
    readonly property color launcherMuted: palette.surfaceVariantForeground
    readonly property color launcherBackground: palette.popupBackground
    readonly property color launcherSurface: palette.surface
    readonly property color launcherSurfaceHover: palette.surfaceHover
    readonly property color launcherPrimary: palette.primary
    readonly property color launcherBlue: palette.blue
    readonly property color launcherGreen: palette.green
    readonly property color launcherPink: palette.pink
    readonly property color launcherOrange: palette.orange
    readonly property color launcherYellow: palette.yellow
    readonly property color launcherRed: palette.red
    readonly property color launcherCyan: palette.cyan

    property string query: searchInput.text
    property bool appBrowserMode: false
    property string appBrowserCategory: "all"
    property bool categoryMenuOpen: false
    property bool modeMenuOpen: false
    property bool systemInfoOpen: false
    property int modeMenuIndex: 0
    readonly property var modeOptions: [
        { prefix: "@", label: "Arquivos" },
        { prefix: "#", label: "Área de transferência" },
        { prefix: "~", label: "Janelas" },
        { prefix: ":", label: "Ações" },
        { prefix: ";", label: "Emojis" },
        { prefix: "!", label: "Encerrar aplicativo" },
        { prefix: ">", label: "Terminal" },
        { prefix: "=", label: "Calculadora" }
    ]
    readonly property string appBrowserCategoryLabel: {
        const category = AppCategoryLogic.categories.find(item => item.id === root.appBrowserCategory)
        return category?.label ?? "Todos"
    }
    // Open-latency budget guard (validate.sh warns past 150ms).
    property double openRequestedAt: 0
    // Raycast-style emoji grid cursor (emojiMode only).
    property int emojiIndex: 0
    readonly property int emojiColumns: 8
    readonly property int appBrowserHeight: Math.min(
        520,
        Math.max(180, root.height - Math.max(82, Math.round(root.height * 0.13)) - 16)
    )
    // Etapa 1 Raycast: barra inferior contextual (com digitação, no modo tema ou no clipboard; vazio na raiz mostra os modos).
    readonly property bool actionBarVisible: !root.modeMenuOpen
        && (root.actionPanelOpen
            || (root.query.trim().length > 0 && root.selectedResult !== null)
            || root.themeMode)
    // Etapa 2 Raycast: painel de ações.
    property bool actionPanelOpen: false
    property int actionIndex: 0
    property string panelBaseQuery: ""
    readonly property string actionBarPrimary: {
        if (root.themeMode) {
            return themePane.kbZone === "catalog" ? "Aplicar tema"
                : themePane.kbZone === "variant" ? "Aplicar variante"
                : themePane.kbZone === "colors" ? "Aplicar cor"
                : themePane.kbZone === "glass" ? "Restaurar vidro padrão"
                : "Aplicar papel de parede"
        }
        const a = actionRegistry.primaryAction(root.selectedResult)
        return a ? String(a.title ?? "") : ""
    }
    readonly property string themeStudioActionText: {
        if (themePane.kbZone === "gallery")
            return "Aplicar papel de parede"
        if (themePane.kbZone === "variant")
            return "Aplicar estilo"
        if (themePane.kbZone === "colors")
            return "Aplicar tom"
        if (themePane.kbZone === "glass")
            return "Restaurar vidro padrão"
        return "Aplicar paleta"
    }
    readonly property string actionBarSecondary: {
        if (root.themeMode)
            return ""
        const a = actionRegistry.secondaryAction(root.selectedResult)
        return a ? String(a.title ?? "") : ""
    }
    property int selectedIndex: {
        if (results.length === 0)
            return -1
        if (root.emojiMode)
            return Math.min(Math.max(0, root.emojiIndex), results.length - 1)
        return Math.min(Math.max(0, resultList.currentIndex), results.length - 1)
    }
    readonly property var selectedResult: (selectedIndex >= 0 && selectedIndex < results.length)
                                         ? results[selectedIndex]
                                         : null

    readonly property string queryMode: ModeLogic.modeForQuery(query)
    readonly property bool commandMode: queryMode === "command"
    readonly property bool calcMode: queryMode === "calculation"
    readonly property bool fileMode: queryMode === "files"
    readonly property bool clipboardMode: queryMode === "clipboard"
    readonly property bool actionMode: queryMode === "actions" || queryMode === "themes"
    readonly property bool themeMode: queryMode === "themes"
    readonly property bool emojiMode: queryMode === "emoji"
    readonly property bool killMode: queryMode === "kill"
    readonly property bool windowMode: queryMode === "windows"

    property var appUsage: ({})
    property string clipboardSelectedIdBeforeRefresh: ""

    readonly property var appBrowserApplications: {
        const entries = []
        try {
            for (const entry of [...DesktopEntries.applications.values]) {
                if (!entry || !entry.name || entry.noDisplay) continue
                if (!hasAppIcon(entry)) continue
                entries.push(entry)
            }
        } catch (error) {}
        return entries
    }
    readonly property var results: root.appBrowserMode
                                    ? resultModel.normalizeAll(appBrowserResults(), "apps", actionRegistry)
                                    : queryRouter.results

    // IPC entry points for compositors without GlobalShortcut support
    // (e.g. labwc keybinds call `quickshell ipc call spotlight <fn>`).
    IpcHandler {
        target: "spotlight"

        function toggle(): void { root.toggleLauncher() }        function open(): void { root.openLauncher() }
        function clipboard(): void { root.openWithPrefix("#") }
        function actions(): void { root.openWithPrefix(":") }
        function theme(): void { root.openWithPrefix(":tema ") }
        function config(): void { root.openWithPrefix(":tema ") }
        function emoji(): void { root.openWithPrefix(";") }
        function kill(): void { root.openWithPrefix("!") }
        function windows(): void { root.openWithPrefix("~") }
        function search(q: string): void {
            root.openLauncher()
            searchInput.text = q
        }
    }

    SpotlightActions {
        id: actionCatalog
        palette: palette
    }

    // Etapa 0 Raycast: catálogo declarativo de ações (sem executar nada).
    SpotlightActionCatalog {
        id: actionRegistry
    }

    SpotlightActionExecutor {
        id: actionExecutor
        catalog: actionRegistry
        clipboardService: clipboard
        resultItems: root.results

        onCloseRequested: root.closeLauncher()
        onSystemInfoPopupRequested: {
            root.systemInfoOpen = true
            systemInfoCommand.refresh()
        }
        onNavigateRequested: function(prefix) {
            searchInput.text = prefix
            resultList.currentIndex = 0
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
                searchInput.cursorPosition = searchInput.text.length
            })
        }
        onSessionConfirmationRequested: function(action) {
            sessionConfirmation.openConfirmation(action)
        }
        onDownloadPanelRequested: function(url, mode) {
            downloadPanel.openDownload(url, mode)
        }
        onUsageBumpRequested: function(appName) {
            usageBumpProc.command = [
                "python3",
                Quickshell.shellDir + "/scripts/launcher-data.py",
                "bump",
                appName
            ]
            if (!usageBumpProc.running)
                usageBumpProc.running = true
        }
        onActivateRequested: function(index) { root.activate(index) }
    }

    SpotlightSearch {
        id: search
    }

    SpotlightResult {
        id: resultModel
    }

    SpotlightSearchController {
        id: searchController
        searchLogic: search
        normalizer: resultModel
        actions: actionRegistry
        commandsCatalog: actionCatalog
    }

    SpotlightQueryRouter {
        id: queryRouter
        query: root.query
        searchLogic: search
        clipboard: clipboard
        downloadState: DownloadState
        modes: modes
        actionCatalog: actionCatalog
        searchController: searchController
        applicationEntries: DesktopEntries.applications.values
        appUsage: root.appUsage
        normalizer: resultModel
        actionRegistry: actionRegistry
    }

    SpotlightClipboard {
        id: clipboard
        active: root.clipboardMode
        visibleResults: root.results
    }

    SpotlightModes {
        id: modes
    }

    Connections {
        target: clipboard

        function onRestoreSucceeded() {
            if (clipboard.stayOpenOnce) {
                clipboard.stayOpenOnce = false
                return
            }
            if (root.visible && root.clipboardMode)
                root.closeLauncher()
        }

        function onImageOpenSucceeded() {
            if (root.visible && root.clipboardMode)
                root.closeLauncher()
        }

        function onItemsReplacing() {
            const selected = root.selectedResult
            root.clipboardSelectedIdBeforeRefresh = selected && selected.kind === "clipboard"
                                                    ? String(selected.payload.clipId) : ""
        }

        function onItemsReplaced() {
            const selectedId = root.clipboardSelectedIdBeforeRefresh
            root.clipboardSelectedIdBeforeRefresh = ""
            if (!selectedId || !root.visible || !root.clipboardMode)
                return
            const index = root.results.findIndex(item =>
                item.kind === "clipboard" && String(item.payload.clipId) === selectedId)
            if (index >= 0)
                resultList.currentIndex = index
        }
    }


    function deleteCurrentClipboardItem() {
        if (!root.clipboardMode)
            return

        const item = root.selectedResult
        if (!item || item.kind !== "clipboard"
                || item.payload.clipId === undefined || item.payload.clipId === null)
            return

        clipboard.removeItem(String(item.payload.clipId), String(item.payload.clipSignature ?? ""))

        if (resultList.currentIndex >= root.results.length) {
            resultList.currentIndex = Math.max(0, root.results.length - 1)
        }
    }

    function closeLauncher() {
        if (root.systemInfoOpen || !root.visible || root.closingAnimation)
            return
        root.closingAnimation = true
        closeAnimationTimer.start()
        root.appBrowserMode = false
        root.appBrowserCategory = "all"
        root.categoryMenuOpen = false
        root.modeMenuOpen = false
        root.actionPanelOpen = false
        root.actionIndex = 0
        searchInput.text = ""
        resultList.currentIndex = 0
    }

    function openLauncher() {
        closeAnimationTimer.stop()
        root.closingAnimation = false
        root.openRequestedAt = Date.now()
        root.visible = true
        root.appBrowserMode = false
        root.appBrowserCategory = "all"
        root.categoryMenuOpen = false
        root.modeMenuOpen = false
        root.actionPanelOpen = false
        root.actionIndex = 0
        searchInput.text = ""
        resultList.currentIndex = 0
        modes.refreshWindows()
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    function toggleLauncher() {
        if (root.visible)
            closeLauncher()
        else
            openLauncher()
    }

    function hasAppIcon(entry) {
        try {
            return AppIconResolver.resolve(
                       entry?.icon,
                       Quickshell.iconPath(String(entry?.icon ?? ""), true)).length > 0
        } catch (error) {
            return true
        }
    }

    function appBrowserResults() {
        const query = String(root.query ?? "").trim()
        const values = []
        for (const entry of root.appBrowserApplications) {
            if (!AppCategoryLogic.matchesCategory(entry, root.appBrowserCategory))
                continue

            const score = query.length > 0 ? search.scoreEntry(entry, query, root.appUsage) : 0
            if (query.length > 0 && score <= 0)
                continue

            const category = AppCategoryLogic.categories.find(
                item => item.id === AppCategoryLogic.bucketOf(entry))
            values.push({
                kind: "app",
                title: String(entry.name ?? ""),
                subtitle: String(entry.genericName ?? entry.comment ?? "").trim(),
                icon: entry.icon,
                entry: entry,
                score: score,
                section: "Aplicativo",
                category: category?.label ?? "Outros"
            })
        }

        values.sort((left, right) => {
            if (query.length > 0 && right.score !== left.score)
                return right.score - left.score
            return left.title.localeCompare(right.title)
        })
        return values
    }

    function openAppsBrowser() {
        root.openRequestedAt = Date.now()
        if (!root.appBrowserMode)
            root.appBrowserCategory = "all"
        root.appBrowserMode = true
        root.categoryMenuOpen = true
        root.modeMenuOpen = false
        root.actionPanelOpen = false
        root.visible = true
        resultList.currentIndex = 0
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    function returnToUniversalSearch() {
        const selected = root.selectedResult
        const selectedAppKey = String(
            selected?.entry?.id ?? selected?.entry?.name ?? selected?.title ?? ""
        )
        root.appBrowserMode = false
        root.appBrowserCategory = "all"
        root.categoryMenuOpen = false
        root.modeMenuOpen = false
        Qt.callLater(function() {
            const matchingIndex = root.results.findIndex(item => String(
                item.entry?.id ?? item.entry?.name ?? item.title ?? ""
            ) === selectedAppKey)
            if (matchingIndex >= 0)
                resultList.currentIndex = matchingIndex
        })
    }

    // Scroll the selection into view on the next tick, after delegates
    // applied their (possibly expanded) heights. Direct calls race layout
    // and leave tall rows half-hidden.
    function settleSelection() {
        Qt.callLater(function() {
            resultList.positionViewAtIndex(resultList.currentIndex, ListView.Contain)
        })
    }

    function openWithPrefix(prefix) {
        root.openRequestedAt = Date.now()
        root.appBrowserMode = false
        root.appBrowserCategory = "all"
        root.categoryMenuOpen = false
        root.modeMenuOpen = false
        root.actionPanelOpen = false
        const text = prefix.endsWith(" ") ? prefix : (prefix + " ")
        searchInput.text = text
        resultList.currentIndex = 0
        // Set the mode before mapping the window so the first frame never
        // computes and lays out universal-search results that will be discarded.
        root.visible = true

        if (prefix.trim() === ";")
            modes.searchEmoji(prefix.endsWith(" ") ? prefix : (prefix + " "))
        else if (prefix.trim() === "!" || prefix.trim() === "~")
            modes.refreshWindows()
        else if (prefix.trim() === "#")
            clipboard.refresh()

        Qt.callLater(function() {
            searchInput.forceActiveFocus()
            searchInput.cursorPosition = searchInput.text.length
        })
    }

    function activate(index) {
        if (index < 0 || index >= results.length)
            return
        actionExecutor.activate(results[index])
    }

    Process {
        id: usageLoadProc
        command: [
            "python3",
            Quickshell.shellDir + "/scripts/launcher-data.py",
            "usage"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                root.appUsage = response.ok ? (response.data.usage ?? ({})) : ({})
            }
        }
    }

    Process {
        id: usageBumpProc
        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                if (response.ok)
                    root.appUsage = response.data.usage ?? root.appUsage
            }
        }
    }


    Component.onCompleted: {
        if (!usageLoadProc.running)
            usageLoadProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            resultList.currentIndex = 0

            if (root.openRequestedAt > 0) {
                console.log("Spotlight open latency: "
                    + Math.max(0, Math.round(Date.now() - root.openRequestedAt)) + "ms")
                root.openRequestedAt = 0
            }
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
            focusRetry.attempts = 0
            focusRetry.start()
        } else {
            focusRetry.stop()
            root.closingAnimation = false
        }
    }

    Timer {
        id: closeAnimationTimer
        interval: palette.qmlAnimationsEnabled ? palette.motionPopupExit : 0
        onTriggered: root.visible = false
    }

    onSelectedResultChanged: {
        root.actionIndex = 0
    }

    // Compositors without GlobalShortcut activation (e.g. labwc, driven via
    // `quickshell ipc call spotlight …`) may map the layer surface before
    // transferring keyboard focus, so a single Qt.callLater request can land
    // while the window is still inactive. Retry briefly until the input
    // actually holds active focus, then stop. No-op on Hyprland, where the
    // first request already succeeds.
    Timer {
        id: focusRetry
        interval: 60
        repeat: true
        property int attempts: 0
        onTriggered: {
            if (!root.visible || searchInput.activeFocus) {
                attempts = 0
                stop()
                return
            }
            if (++attempts > 8) {
                attempts = 0
                stop()
                return
            }
            searchInput.forceActiveFocus()
        }
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight"
        description: "Toggle Quickshell Spotlight launcher"
        onPressed: root.toggleLauncher()
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight-emoji"
        description: "Open Spotlight emoji picker"
        onPressed: root.openWithPrefix(";")
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight-kill"
        description: "Open Spotlight window killer"
        onPressed: root.openWithPrefix("!")
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight-actions"
        description: "Open Spotlight actions"
        onPressed: root.openWithPrefix(":")
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight-clipboard"
        description: "Open Spotlight clipboard history"
        onPressed: root.openWithPrefix("#")
    }

    // qmllint disable unresolved-type
    GlobalShortcut {
        // qmllint enable unresolved-type
        appid: "quickshell"
        name: "spotlight-windows"
        description: "Open Spotlight window switcher"
        onPressed: root.openWithPrefix("~")
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!root.systemInfoOpen)
                    root.closeLauncher()
            }
        }
    }

    Item {
        id: systemInfoAnchor
        width: 1
        height: 1
        anchors.centerIn: parent
    }

    CommandJson {
        id: systemInfoCommand
        interval: 0
        autoStart: false
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/system-info.py"]
    }

    SystemInfoPopup {
        id: systemInfoPopup
        theme: palette
        target: systemInfoAnchor
        commandResult: systemInfoCommand.result
        opened: root.systemInfoOpen && root.visible
        onCloseRequested: {
            root.systemInfoOpen = false
            Qt.callLater(function() { searchInput.forceActiveFocus() })
        }
    }

    Item {
        id: centerAnchor
        width: root.themeMode ? Math.min(1000, parent.width - 32)
               : root.emojiMode && root.actionPanelOpen && root.selectedResult !== null ? 1000
               : (root.clipboardMode || (root.actionPanelOpen && root.selectedResult !== null)) ? 820
               : (root.emojiMode ? 600 : 560)
        height: card.height

        Behavior on width {
            enabled: palette.qmlAnimationsEnabled
            NumberAnimation { duration: palette.motionFast; easing.type: palette.motionEasing }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(82, Math.round(parent.height * 0.13))

        Rectangle {
            id: glow
            anchors.fill: card
            anchors.margins: -5
            radius: palette.radiusPopup
            color: palette.withAlpha(palette.primary, 0.038)
            border.width: 1
            border.color: palette.withAlpha(palette.primary, 0.055)
            opacity: root.visible && !root.closingAnimation ? 1 : 0
            scale: root.visible && !root.closingAnimation ? 1 : palette.motionPopupScale
            Behavior on opacity { enabled: palette.qmlAnimationsEnabled; NumberAnimation { duration: palette.motionPopupExit; easing.type: Easing.InOutSine } }
            Behavior on scale { enabled: palette.qmlAnimationsEnabled; NumberAnimation { duration: palette.motionPopupExit; easing.type: palette.motionEasing } }
        }

        Rectangle {
            id: card
            width: parent.width
            height: root.emojiMode && root.actionPanelOpen
                    ? Math.max(480, 117 + Math.max(1, Math.ceil(Math.min(root.results.length, 40) / root.emojiColumns)) * 70)
                    : root.emojiMode
                    ? (117 + Math.max(1, Math.ceil(Math.min(root.results.length, 40) / root.emojiColumns)) * 70)
                    : root.themeMode ? Math.min(600, Math.max(400, themePane.preferredHeight + 94), root.height - centerAnchor.anchors.topMargin - 32)
                    : root.clipboardMode ? 500
                    : root.appBrowserMode ? root.appBrowserHeight
                    : (root.actionPanelOpen && root.selectedResult !== null) ? 480
                    : (94
                       + (root.results.length > 0
                          ? Math.min(root.results.length, 6) * 49 + 7
                          : 70))

            Behavior on height {
                // Super+A opens a fixed actions mode. Avoid making the
                // launcher feel delayed while its first results are laid out.
                enabled: palette.qmlAnimationsEnabled && !root.actionMode
                NumberAnimation { duration: palette.motionFast; easing.type: palette.motionEasing }
            }

            radius: palette.radiusPopup
            color: root.launcherBackground
            border.width: 1
            border.color: palette.borderPopup
            clip: true
            opacity: root.visible && !root.closingAnimation ? 1 : 0
            scale: root.visible && !root.closingAnimation ? 1 : palette.motionPopupScale
            transformOrigin: Item.Center

            Behavior on opacity { enabled: palette.qmlAnimationsEnabled; NumberAnimation { duration: root.closingAnimation ? palette.motionPopupExit : palette.motionPopup; easing.type: palette.motionTransientFadeEasing } }
            Behavior on scale { enabled: palette.qmlAnimationsEnabled; NumberAnimation { duration: root.closingAnimation ? palette.motionPopupExit : palette.motionPopup; easing.type: palette.motionEasing } }

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    mouse.accepted = true
                    searchInput.forceActiveFocus()
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0

                Item {
                    width: parent.width
                    height: 58

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: palette.spacingTokens.hero
                        anchors.rightMargin: palette.spacingTokens.xxxl
                        spacing: palette.spacingTokens.xxlPlus

                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            TablerIcon {
                                width: 22
                                height: 22
                                anchors.centerIn: parent
                                visible: !root.appBrowserMode && !root.commandMode && !root.calcMode && !root.fileMode && !root.clipboardMode && !root.actionMode && !root.emojiMode && !root.killMode && !root.windowMode
                                iconName: "search"
                                iconColor: root.launcherPrimary
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.appBrowserMode || root.commandMode || root.calcMode || root.fileMode || root.clipboardMode || root.actionMode || root.emojiMode || root.killMode || root.windowMode
                                text: root.appBrowserMode ? "󰀻" : (root.themeMode ? "󰔎"
                                      : (root.commandMode ? ""
                                      : (root.calcMode ? "󰪚"
                                         : (root.fileMode ? "󰈔"
                                            : (root.clipboardMode ? "󰅇"
                                               : (root.emojiMode ? "󰞅"
                                                  : (root.killMode ? "󰅖"
                                                     : (root.windowMode ? "󰖯" : "󰒓"))))))))
                                color: root.killMode ? palette.error : root.launcherPrimary
                                font.family: palette.nerdFontFamily
                                font.pixelSize: palette.spotlightIconTokens.mode
                            }
                        }

                        SearchField {
                            id: searchInput
                            theme: palette
                            placeholderText: root.appBrowserMode ? "Buscar aplicativos" : "Buscar"
                            placeholderColor: root.launcherMuted

                            width: Math.max(
                                100,
                                parent.width - 24 - modePill.width - powerQuickBtn.width
                                    - 3 * parent.spacing
                            )
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter

                            color: root.launcherForeground
                            selectionColor: palette.withAlpha(palette.primary, 0.38)
                            selectedTextColor: palette.surfaceForeground

                            font.family: palette.fontFamily
                            font.pixelSize: palette.spotlightQueryFontSize
                            font.weight: Font.Medium

                            clip: true

                            onTextChanged: {
                                resultList.currentIndex = 0
                                if (root.modeMenuOpen)
                                    root.modeMenuOpen = false

                                if (root.appBrowserMode && /^[@#;!~=>:]/.test(root.query.trim())) {
                                    root.appBrowserMode = false
                                    root.appBrowserCategory = "all"
                                    root.categoryMenuOpen = false
                                    root.actionPanelOpen = false
                                }

                                if (root.fileMode)
                                    modes.searchFiles(root.query)

                                if (root.clipboardMode) {
                                    if (!clipboard.loaded
                                            && !clipboard.snapshotRunning)
                                        clipboard.refresh()
                                    else
                                        clipboard.scheduleThumbnails()
                                }

                                if (root.emojiMode)
                                    modes.searchEmoji(root.query)

                                if (root.killMode || root.windowMode)
                                    modes.refreshWindows()

                                if (root.actionPanelOpen)
                                    root.actionIndex = 0
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Slash
                                        && (event.modifiers & Qt.ControlModifier)) {
                                    root.modeMenuOpen = !root.modeMenuOpen
                                    if (root.modeMenuOpen) {
                                        root.modeMenuIndex = 0
                                        root.categoryMenuOpen = false
                                        root.actionPanelOpen = false
                                    }
                                    event.accepted = true
                                } else if (root.modeMenuOpen
                                           && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                    const direction = event.key === Qt.Key_Down ? 1 : -1
                                    const count = root.modeOptions.length
                                    root.modeMenuIndex = (root.modeMenuIndex + direction + count) % count
                                    event.accepted = true
                                } else if (root.modeMenuOpen
                                           && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    const selectedMode = root.modeOptions[root.modeMenuIndex]
                                    if (selectedMode)
                                        root.openWithPrefix(selectedMode.prefix)
                                    event.accepted = true
                                } else if (root.modeMenuOpen && event.key === Qt.Key_Escape) {
                                    root.modeMenuOpen = false
                                    event.accepted = true
                                } else if (root.categoryMenuOpen
                                        && event.key === Qt.Key_K
                                        && (event.modifiers & Qt.ControlModifier)
                                        && root.selectedResult !== null) {
                                    root.categoryMenuOpen = false
                                    root.modeMenuOpen = false
                                    root.actionPanelOpen = true
                                    root.actionIndex = 0
                                    root.panelBaseQuery = searchInput.text
                                    event.accepted = true
                                } else if (root.categoryMenuOpen
                                        && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                    categorySidebar.moveSelection(event.key === Qt.Key_Down ? 1 : -1)
                                    event.accepted = true
                                } else if (root.categoryMenuOpen
                                           && (event.key === Qt.Key_Right
                                               || event.key === Qt.Key_Return
                                               || event.key === Qt.Key_Enter)) {
                                    root.categoryMenuOpen = false
                                    event.accepted = true
                                } else if (root.categoryMenuOpen && event.key === Qt.Key_Escape) {
                                    root.categoryMenuOpen = false
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left
                                           && event.modifiers === Qt.NoModifier
                                           && !root.actionPanelOpen && !root.categoryMenuOpen
                                           && !root.commandMode && !root.calcMode && !root.fileMode
                                           && !root.clipboardMode && !root.actionMode && !root.emojiMode
                                           && !root.killMode && !root.windowMode
                                           && searchInput.cursorPosition === 0
                                           && searchInput.selectedText.length === 0) {
                                    root.openAppsBrowser()
                                    event.accepted = true
                                } else if ((event.key === Qt.Key_F6 || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && root.themeMode) {
                                    themePane.toggleKbZone(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier))
                                    event.accepted = true
                                    return
                                } else if (event.key === Qt.Key_K
                                           && (event.modifiers & Qt.ControlModifier)
                                           && root.selectedResult !== null
                                           && !root.themeMode) {
                                    root.modeMenuOpen = false
                                    root.actionPanelOpen = !root.actionPanelOpen
                                    root.actionIndex = 0
                                    if (root.actionPanelOpen)
                                        root.panelBaseQuery = searchInput.text
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Right
                                           && event.modifiers === Qt.NoModifier
                                           && !root.actionPanelOpen
                                           && root.selectedResult !== null
                                           && !root.themeMode && !root.emojiMode
                                           && searchInput.cursorPosition === searchInput.text.length
                                           && searchInput.selectedText.length === 0) {
                                    root.modeMenuOpen = false
                                    root.actionPanelOpen = true
                                    root.actionIndex = 0
                                    root.panelBaseQuery = searchInput.text
                                    event.accepted = true
                                } else if (root.actionPanelOpen
                                           && event.key === Qt.Key_Left
                                           && event.modifiers === Qt.NoModifier) {
                                    root.actionPanelOpen = false
                                    event.accepted = true
                                } else if (root.actionPanelOpen && event.key === Qt.Key_Escape) {
                                    root.actionPanelOpen = false
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape && root.appBrowserMode) {
                                    root.returnToUniversalSearch()
                                    event.accepted = true
                                } else if (root.actionPanelOpen
                                           && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                                    const direction = event.key === Qt.Key_Down ? 1 : -1
                                    root.actionIndex = actionPanel.panelMove(direction)
                                    event.accepted = true
                                } else if (root.actionPanelOpen
                                           && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    const spec = actionPanel.actionAt(root.actionIndex)
                                    if (spec && actionExecutor.runActionById(spec.id, root.selectedResult, root.selectedIndex)) {
                                        root.actionPanelOpen = false
                                        event.accepted = true
                                    }
                                } else if (root.emojiMode
                                           && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                               || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                    if (root.results.length > 0) {
                                        const len = root.results.length
                                        const cur = Math.min(Math.max(0, root.emojiIndex), len - 1)
                                        const column = cur % root.emojiColumns
                                        let next = cur

                                        if (event.key === Qt.Key_Left && column > 0)
                                            next = cur - 1
                                        else if (event.key === Qt.Key_Right
                                                 && column < root.emojiColumns - 1 && cur + 1 < len)
                                            next = cur + 1
                                        else if (event.key === Qt.Key_Up && cur >= root.emojiColumns)
                                            next = cur - root.emojiColumns
                                        else if (event.key === Qt.Key_Down && cur + root.emojiColumns < len)
                                            next = cur + root.emojiColumns

                                        root.emojiIndex = next
                                    }
                                    event.accepted = true
                                } else if (root.themeMode && (event.key === Qt.Key_Right || event.key === Qt.Key_Left)) {
                                    if (themePane.kbZone === "glass")
                                        themePane.glassMove(event.key === Qt.Key_Right ? 1 : -1)
                                    else if (themePane.kbZone === "colors")
                                        themePane.colorMove(event.key === Qt.Key_Right ? 1 : -1)
                                    else if (themePane.kbZone === "variant")
                                        themePane.variantMove(event.key === Qt.Key_Right ? 1 : -1)
                                    else if (themePane.kbZone === "actions")
                                        themePane.colorActionMove(event.key === Qt.Key_Right ? 1 : -1)
                                    else if (themePane.kbZone === "catalog")
                                        themePane.catMove(event.key === Qt.Key_Right ? 1 : -1, 0)
                                    else
                                        themePane.wpMove(event.key === Qt.Key_Right ? 1 : -1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    if (root.themeMode) {
                                        if (themePane.kbZone === "glass")
                                            themePane.glassMove(1)
                                        else if (themePane.kbZone === "colors")
                                            themePane.colorMove(1)
                                        else if (themePane.kbZone === "variant")
                                            themePane.variantMove(1)
                                        else if (themePane.kbZone === "actions")
                                            themePane.colorActionMove(1)
                                        else if (themePane.kbZone === "catalog")
                                            themePane.catMove(0, 1)
                                        else
                                            themePane.wpMove(1)
                                    } else if (root.results.length > 0) {
                                        resultList.currentIndex =
                                            (resultList.currentIndex + 1) % root.results.length
                                        root.settleSelection()
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    if (root.themeMode) {
                                        if (themePane.kbZone === "glass")
                                            themePane.glassMove(-1)
                                        else if (themePane.kbZone === "colors")
                                            themePane.colorMove(-1)
                                        else if (themePane.kbZone === "variant")
                                            themePane.variantMove(-1)
                                        else if (themePane.kbZone === "actions")
                                            themePane.colorActionMove(-1)
                                        else if (themePane.kbZone === "catalog")
                                            themePane.catMove(0, -1)
                                        else
                                            themePane.wpMove(-1)
                                    } else if (root.results.length > 0) {
                                        resultList.currentIndex =
                                            (resultList.currentIndex - 1 + root.results.length)
                                            % root.results.length
                                        root.settleSelection()
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageDown) {
                                    if (root.results.length > 0) {
                                        resultList.currentIndex =
                                            Math.min(root.results.length - 1, resultList.currentIndex + 6)
                                        root.settleSelection()
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_PageUp) {
                                    if (root.results.length > 0) {
                                        resultList.currentIndex =
                                            Math.max(0, resultList.currentIndex - 6)
                                        root.settleSelection()
                                    }
                                    event.accepted = true
                                } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Back)
                                           && (event.modifiers & Qt.ShiftModifier)) {
                                    if (root.clipboardMode) {
                                        root.deleteCurrentClipboardItem()
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Delete
                                           && root.clipboardMode
                                           && searchInput.cursorPosition >= searchInput.text.length
                                           && searchInput.selectedText.length === 0) {
                                    root.deleteCurrentClipboardItem()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return
                                           && (event.modifiers & Qt.ControlModifier)) {
                                    if (actionExecutor.runSecondary(root.selectedResult)) {
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Return
                                           || event.key === Qt.Key_Enter) {
                                    if (root.emojiMode && root.results.length > 0) {
                                        root.emojiIndex = Math.min(Math.max(0, root.emojiIndex), root.results.length - 1)
                                        root.activate(root.emojiIndex)
                                        event.accepted = true
                                    } else if (root.themeMode) {
                                        let done = true
                                        if (["colors", "variant", "actions", "glass"].includes(themePane.kbZone))
                                            themePane.activatePaletteControl()
                                        else if (themePane.kbZone === "catalog")
                                            done = themePane.catActivateSelected()
                                        else
                                            done = themePane.wpActivateSelected()
                                        if (!done)
                                            root.activate(resultList.currentIndex)
                                        event.accepted = true
                                    } else {
                                        root.activate(resultList.currentIndex)
                                        event.accepted = true
                                    }
                                } else if (
                                    event.key === Qt.Key_C
                                    && (event.modifiers & Qt.ControlModifier)
                                    && root.calcMode
                                ) {                                    const value = searchInput.selectedText.length > 0
                                                  ? searchInput.selectedText
                                                  : searchInput.text.replace(/^=/, "").trim()

                                    if (value.length > 0)
                                        Quickshell.execDetached(["wl-copy", value])

                                    event.accepted = true
                                } else if (event.key === Qt.Key_Backspace
                                           && (searchInput.text === ":tema "
                                               || searchInput.text === ":tela "
                                               || searchInput.text === ":captura "
                                               || searchInput.text === ":luz "
                                               || searchInput.text === ":energia "
                                               || searchInput.text === ":conexoes "
                                               || searchInput.text === ":sistema "
                                               || searchInput.text === ":sessao ")) {
                                    searchInput.text = ": "
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    if (root.themeMode && themePane.colorMode)
                                        themePane.cancelColorPreview()
                                    else
                                        root.closeLauncher()
                                    event.accepted = true
                                }
        }
    }

    Rectangle {
                            id: modePill
                            anchors.verticalCenter: parent.verticalCenter
                            // Keep the mode label and gear aligned across modes.
                            // Without a minimum width, short labels like "Apps"
                            // pull the gear left compared with "Configurações".
                            width: Math.max(modeText.implicitWidth + 10, 72)
                            height: 20
                            radius: palette.radiusSm

                            readonly property bool activeCategory: root.appBrowserMode
                                && root.appBrowserCategory !== "all"
                            color: activeCategory
                                   ? palette.primaryContainer
                                   : (modeHover.hovered ? palette.glassHoverSurface : "transparent")
                            border.width: activeCategory ? 1 : 0
                            border.color: palette.outlineVariant

                            HoverHandler {
                                id: modeHover
                                cursorShape: modePill.activeCategory ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                enabled: modePill.activeCategory
                                onTapped: {
                                    root.appBrowserCategory = "all"
                                    resultList.currentIndex = 0
                                }
                            }

                            Text {
                                id: modeText
                                anchors.centerIn: parent
                                text: {
                                    if (root.appBrowserMode)
                                        return modePill.activeCategory
                                            ? root.appBrowserCategoryLabel + " ×"
                                            : "Apps"
                                    if (root.commandMode) return "Comando"
                                    if (root.calcMode) return "Cálculo"
                                    if (root.fileMode) return "Arquivos"
                                    if (root.clipboardMode) return "Área de transferência"
                                    if (root.actionMode) return queryRouter.getActionModeTitle(root.query)
                                    if (root.emojiMode) return "Emoji"
                                    if (root.killMode) return "Encerrar aplicativo"
                                    if (root.windowMode) return "Janelas"
                                    return root.query.trim().length > 0 ? "Tudo" : "Apps"
                                }
                                color: modePill.activeCategory
                                       ? palette.primaryContainerForeground
                                       : root.launcherMuted
                                font.family: palette.fontFamily
                                font.pixelSize: palette.spotlightLabelFontSize
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            id: powerQuickBtn
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: palette.radiusButton

                            color: root.actionMode
                                   ? palette.glassActiveSurface
                                   : (powerHover.hovered
                                      ? palette.glassHoverSurface
                                      : palette.glassCardSurface)
                            border.width: 1
                            border.color: root.actionMode ? palette.outlineVariant : palette.pillBorder

                            HoverHandler {
                                id: powerHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: {
                                    if (root.actionMode) {
                                        searchInput.text = ""
                                    } else {
                                        root.openWithPrefix(":")
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: palette.nerdFontFamily
                                font.pixelSize: palette.spotlightIconTokens.mode
                                color: root.actionMode ? palette.primaryContainerForeground : root.launcherPrimary
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 28
                    height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: palette.outlineVariant
                }

                Item {
                    id: contentArea
                    width: parent.width
                    height: card.height - 94

                    // LEFT PANE: List of results (hidden in theme mode;
                    // keyboard nav still works through the model)
                    Item {
                        id: listContainer
                        visible: !root.themeMode
                        width: root.clipboardMode ? 380
                               : (root.actionPanelOpen && root.selectedResult !== null)
                                 ? (root.emojiMode ? 600 : 380)
                               : (root.themeMode ? 0 : parent.width)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                            AppCategorySidebar {
                                id: categorySidebar
                                visible: root.categoryMenuOpen
                                x: 8
                                y: 8
                                width: 148
                                height: parent.height - 12
                                theme: palette
                                applications: root.appBrowserApplications
                                selectedCategory: root.appBrowserCategory
                                onCategorySelected: function(categoryId) {
                                    root.appBrowserCategory = categoryId
                                    root.categoryMenuOpen = false
                                    resultList.currentIndex = 0
                                }
                                onCategoryHighlighted: function(categoryId) {
                                    root.appBrowserCategory = categoryId
                                    resultList.currentIndex = 0
                                }
                            }

                            Rectangle {
                                visible: root.categoryMenuOpen
                                x: 158
                                y: 8
                                width: 1
                                height: parent.height - 16
                                color: palette.outlineVariant
                            }

                        EmptyState {
                            anchors.centerIn: resultList
                            visible: root.results.length === 0
                            theme: palette
                            title: "Nenhum resultado"
                            titleColor: root.launcherSecondary
                            titleSize: palette.spotlightBodyFontSize
                        }

                        ListView {
                            id: resultList
                            visible: !root.emojiMode || root.results.length === 0 || root.results[0].kind !== "emoji"

                            anchors.fill: parent
                            anchors.leftMargin: root.categoryMenuOpen ? 166 : 8
                            anchors.rightMargin: (root.clipboardMode || root.themeMode || (root.actionPanelOpen && root.selectedResult !== null)) ? 4 : 8
                            anchors.topMargin: palette.spacingTokens.smPlus
                            anchors.bottomMargin: palette.spacingTokens.tiny

                            model: root.results
                            currentIndex: 0

                            WheelKinetic { scrollTarget: resultList }

                            clip: true
                            spacing: palette.spacingTokens.tiny
                            keyNavigationWraps: true
                            interactive: contentHeight > height

                            highlightMoveDuration: 90
                            highlightResizeDuration: 90

                            highlight: Rectangle {
                                radius: palette.radiusMd
                                color: root.selectedResult?.kind === "kill"
                                       || root.selectedResult?.kind === "close_window"
                                       ? palette.errorContainer
                                       : palette.primaryContainer
                                border.width: 0
                            }

                            delegate: LauncherItemDelegate {
                                themeColors: palette
                                showProvider: !root.fileMode && !root.clipboardMode
                                              && !root.actionMode && !root.commandMode
                                              && !root.calcMode && !root.emojiMode
                                              && !root.killMode && !root.windowMode
                                              && root.query.trim().length > 0
                                currentIndex: resultList.currentIndex
                                launcherForeground: root.launcherForeground
                                launcherSecondary: root.launcherSecondary
                                launcherMuted: root.launcherMuted
                                onActivated: function(idx) {
                                    if (root.clipboardMode) {
                                        if (resultList.currentIndex === idx) {
                                            root.activate(idx)
                                        } else {
                                            resultList.currentIndex = idx
                                        }
                                    } else {
                                        resultList.currentIndex = idx
                                        // Keep the newly expanded row fully visible.
                                        root.settleSelection()
                                        root.activate(idx)
                                    }
                                }
                            }
                        }

                        // Raycast-style emoji grid (emojiMode only).
                        Flow {
                            id: emojiGrid
                            visible: root.emojiMode && root.results.length > 0 && root.results[0].kind === "emoji"
                            anchors.fill: parent
                            anchors.leftMargin: palette.spacingTokens.xxl
                            anchors.rightMargin: palette.spacingTokens.xxl
                            anchors.topMargin: palette.spacingTokens.lg
                            anchors.bottomMargin: palette.spacingTokens.sm
                            spacing: palette.spacingTokens.sm

                            Repeater {
                                model: root.results

                                delegate: Rectangle {
                                    id: emojiResultDelegate
                                    required property var modelData
                                    required property int index
                                    width: (emojiGrid.width - ((root.emojiColumns - 1) * emojiGrid.spacing)) / root.emojiColumns
                                    height: 64
                                    radius: palette.radiusLg
                                    color: index === root.emojiIndex
                                           ? palette.primaryContainer
                                           : (emojiHov.containsMouse
                                              ? palette.stateLayer(palette.surfaceForeground, "hover")
                                              : "transparent")
                                    border.width: index === root.emojiIndex ? 1 : 0
                                    border.color: palette.outlineVariant

                                    Text {
                                        anchors.centerIn: parent
                                        text: emojiResultDelegate.modelData.payload.emoji ?? ""
                                        font.pixelSize: palette.spotlightIconTokens.emoji
                                    }

                                    MouseArea {
                                        id: emojiHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onContainsMouseChanged: {
                                            if (containsMouse)
                                                root.emojiIndex = emojiResultDelegate.index
                                        }
                                        onClicked: {
                                            root.emojiIndex = emojiResultDelegate.index
                                            root.activate(emojiResultDelegate.index)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // DIVIDER: Visible in clipboard mode & action panel mode
                    Rectangle {
                        id: clipboardDivider
                        visible: root.clipboardMode || (root.actionPanelOpen && root.selectedResult !== null && !root.themeMode)
                        width: 1
                        anchors.left: root.themeMode ? parent.left : listContainer.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: palette.spacingTokens.xs
                        anchors.bottomMargin: palette.spacingTokens.xs
                        color: palette.outlineVariant
                    }

                    // RIGHT PANE: Live Preview (Raycast/Alfred style)
                    ClipboardPreview {
                        id: previewPane
                        visible: root.clipboardMode && !root.actionPanelOpen
                        anchors.left: clipboardDivider.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: palette.spacingTokens.xl
                        anchors.rightMargin: palette.spacingTokens.xl
                        anchors.topMargin: palette.spacingTokens.sm
                        anchors.bottomMargin: palette.spacingTokens.sm
                        themeColors: palette
                        result: root.selectedResult
                        store: clipboard
                        active: root.clipboardMode
                        onDeleteRequested: root.deleteCurrentClipboardItem()
                        onOpenImageRequested: {
                            if (result && result.kind === "clipboard")
                                clipboard.openImage(
                                    String(result.payload.clipId ?? ""),
                                    String(result.payload.clipSignature ?? "")
                                )
                        }
                        onPasteRequested: {
                            if (resultList.currentIndex >= 0)
                                root.activate(resultList.currentIndex)
                        }
                    }

                    // RIGHT PANE: Live Theme & Wallpaper Preview (Material You)
                    ThemePreviewPane {
                        id: themePane
                        visible: root.themeMode
                        anchors.left: clipboardDivider.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: palette.spacingTokens.xl
                        anchors.rightMargin: palette.spacingTokens.xl
                        anchors.topMargin: palette.spacingTokens.sm
                        anchors.bottomMargin: palette.spacingTokens.sm
                        themeColors: palette
                        selectedItem: root.selectedResult
                        active: root.themeMode && root.visible
                        filterText: root.query
                        onFolderPickerRequested: root.visible = false
                        onFolderPickerFinished: {
                            root.visible = true
                            searchInput.forceActiveFocus()
                        }
                        onWallpaperSelectionRequested: searchInput.forceActiveFocus()
                    }

                    // RIGHT PANE: Detalhes & Ações Contextuais (Raycast Detail & Actions, Ctrl+K)
                    SpotlightActionPanel {
                        id: actionPanel
                        visible: root.actionPanelOpen && root.selectedResult !== null && !root.themeMode
                        anchors.left: clipboardDivider.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: palette.spacingTokens.xxl
                        anchors.rightMargin: palette.spacingTokens.xxl
                        anchors.topMargin: palette.spacingTokens.md
                        anchors.bottomMargin: palette.spacingTokens.md
                        themeColors: palette
                        categoryLabel: root.selectedResult?.kind === "app"
                                       ? String(root.selectedResult.category ?? "")
                                       : ""
                        actions: actionRegistry.actionsFor(root.selectedResult)
                        currentIndex: root.actionIndex
                        targetItem: root.selectedResult
                        filterText: {
                            const base = root.panelBaseQuery
                            const q = searchInput.text
                            return (base.length > 0 && q.startsWith(base)) ? q.slice(base.length) : ""
                        }
                        onActionChosen: function(actionId) {
                            if (actionExecutor.runActionById(actionId, root.selectedResult, root.selectedIndex))
                                root.actionPanelOpen = false
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 28
                    height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: palette.outlineVariant
                }

                SpotlightActionBar {
                    id: actionBar
                    themeColors: palette
                    modeOptions: root.modeOptions
                    primaryText: root.actionBarVisible
                                 ? (root.themeMode ? root.themeStudioActionText : root.actionBarPrimary)
                                 : (root.selectedResult !== null ? "Abrir" : "")
                    secondaryText: root.actionBarVisible ? root.actionBarSecondary : ""
                    contextText: {
                        if (root.themeMode) {
                            const name = palette.palette?.name ?? palette.currentTheme
                            return "󰔎 " + name + " · " + WallpaperState.wpItems.length + " papéis de parede"
                        }
                        if (!root.selectedResult) return ""
                        const r = root.selectedResult
                        if (r.kind === "clipboard") return "󰅍 Área de transferência · " + root.results.length + " itens"
                        if (r.kind === "system") return "Ações do sistema"
                        if (r.kind === "app") return AppCategoryLogic.contextLabel(r.category)
                        if (r.kind === "window") return "Janelas"
                        if (r.kind === "file") return "Arquivos"
                        if (r.kind === "command") return "Terminal"
                        if (r.kind === "calc") return "Calculadora"
                        if (r.kind === "emoji") {
                            const em = r.payload?.emoji ?? r.icon ?? ""
                            return em ? (em + " Emoji") : "Emojis"
                        }
                        return r.section ?? ""
                    }
                    hasActions: root.actionBarVisible && root.selectedResult !== null
                                && !root.actionPanelOpen && !root.themeMode
                    arrowActions: root.clipboardMode
                    hasSelection: root.selectedResult !== null
                    showCategories: !root.actionBarVisible
                        && !root.commandMode && !root.calcMode
                        && !root.fileMode && !root.clipboardMode && !root.actionMode
                        && !root.emojiMode && !root.killMode && !root.windowMode
                    showModes: !root.actionBarVisible
                    categoryMenuOpen: root.categoryMenuOpen
                    modeMenuOpen: root.modeMenuOpen
                    modeMenuIndex: root.modeMenuIndex
                    onPrimaryClicked: {
                        if (root.themeMode) {
                            themePane.activateStudioPrimary()
                            return
                        }
                        root.activate(root.selectedIndex)
                    }
                    onSecondaryClicked: actionExecutor.runSecondary(root.selectedResult)
                    onActionsClicked: {
                        root.categoryMenuOpen = false
                        root.modeMenuOpen = false
                        root.actionPanelOpen = !root.actionPanelOpen
                        root.actionIndex = 0
                        if (root.actionPanelOpen)
                            root.panelBaseQuery = searchInput.text
                    }
                    onCategoryClicked: {
                        root.actionPanelOpen = false
                        root.modeMenuOpen = false
                        if (root.appBrowserMode)
                            root.categoryMenuOpen = !root.categoryMenuOpen
                        else
                            root.openAppsBrowser()
                    }
                    onModesClicked: {
                        root.modeMenuOpen = !root.modeMenuOpen
                        if (root.modeMenuOpen) {
                            root.modeMenuIndex = 0
                            root.categoryMenuOpen = false
                            root.actionPanelOpen = false
                        }
                    }
                    onModeSelected: function(prefix) {
                        root.modeMenuOpen = false
                        if (prefix.length > 0)
                            root.openWithPrefix(prefix)
                        else if (root.selectedResult !== null)
                            root.activate(root.selectedIndex)
                    }
                }
            }
        }
    }

    // Keep the launcher and its backdrop inert while the system panel is open.
    // The separately anchored PopupWindow remains above this click shield.
    Item {
        anchors.fill: parent
        visible: root.systemInfoOpen
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }
    }
}
