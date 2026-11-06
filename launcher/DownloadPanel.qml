pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

// Small in-Spotlight panel to confirm a yt-dlp download: thumbnail,
// title, duration, then quality/format/destination. Remembers last
// choices through the helper prefs. Mouse-first with basic keyboard
// navigation (Up/Down/Enter/Esc).
PopupWindow {
    id: root

    required property var theme
    required property Item target
    property bool ownerActive: false

    signal doneRequested()
    signal panelDismissed()

    property string pendingUrl: ""
    property string pendingMode: "video"
    property string phase: "idle" // idle|loading|ready|error|starting
    property var info: ({})
    property string loadError: ""
    property string startError: ""
    property int focusIndex: 0

    property var videoQualities: ["best", "1080p", "720p", "480p"]
    property var videoFormats: ["mp4", "mkv"]
    property var audioFormats: ["mp3", "m4a", "opus"]
    property var destOptions: ["~/Downloads", "~/Vídeos", "~/Música"]
    property int qualityIndex: 2
    property int formatIndex: 0
    property int destIndex: 0

    readonly property var formatOptions: root.pendingMode === "audio" ? root.audioFormats : root.videoFormats
    readonly property string pickedQuality: root.pendingMode === "audio" ? "best" : root.videoQualities[Math.min(root.qualityIndex, root.videoQualities.length - 1)]
    readonly property string pickedFormat: root.formatOptions[Math.min(root.formatIndex, root.formatOptions.length - 1)]
    readonly property string pickedDest: root.destOptions[Math.min(root.destIndex, root.destOptions.length - 1)]
    // Confirm row index: 0 quality, 1 format, 2 dest, 3 confirm (quality hidden for audio).
    readonly property int rowCount: root.pendingMode === "audio" ? 3 : 4

    function openDownload(url, mode) {
        root.pendingUrl = String(url ?? "")
        root.pendingMode = String(mode ?? "video") === "audio" ? "audio" : "video"
        root.phase = "loading"
        root.info = {}
        root.loadError = ""
        root.startError = ""
        // Put keyboard focus on the actual primary action. Enter should start
        // the download immediately; users can move up to adjust options.
        root.focusIndex = root.pendingMode === "audio" ? 2 : 3
        root.qualityIndex = 2
        root.formatIndex = 0
        root.destIndex = 0
        prefsFetch.command = ["python3", "-B", Quickshell.shellDir + "/scripts/ytdlp-download.py", "prefs"]
        prefsFetch.refresh()
        infoFetch.command = ["python3", "-B", Quickshell.shellDir + "/scripts/ytdlp-download.py", "info", root.pendingUrl]
        infoFetch.restart()
        root.visible = true
    }

    function applyPrefs(prefs) {
        const q = String(prefs?.quality ?? "")
        const f = String(prefs?.format ?? "")
        const d = String(prefs?.dest ?? "")
        const qi = root.videoQualities.indexOf(q)
        if (qi >= 0)
            root.qualityIndex = qi
        const fi = root.formatOptions.indexOf(f)
        if (fi >= 0)
            root.formatIndex = fi
        const di = root.destOptions.indexOf(d)
        root.destIndex = di >= 0 ? di : 0
    }

    function cycleRow(index) {
        // Row order mirrors rowCount: quality?, format, dest, confirm.
        const audio = root.pendingMode === "audio"
        const row = audio ? index + 1 : index
        if (row === 0)
            root.qualityIndex = (root.qualityIndex + 1) % root.videoQualities.length
        else if (row === 1)
            root.formatIndex = (root.formatIndex + 1) % root.formatOptions.length
        else if (row === 2)
            root.destIndex = (root.destIndex + 1) % root.destOptions.length
        else
            root.confirm()
    }

    function confirm() {
        if (root.phase !== "ready")
            return
        root.phase = "starting"
        root.startError = ""
        startRun.command = ["python3", "-B", Quickshell.shellDir + "/scripts/ytdlp-download.py",
                            "start", root.pendingUrl,
                            "--mode", root.pendingMode,
                            "--quality", root.pickedQuality,
                            "--format", root.pickedFormat,
                            "--dest", root.pickedDest,
                            "--thumbnail", String(root.info?.thumbnail ?? "")]
        startRun.refresh()
    }

    function close() {
        root.visible = false
        root.phase = "idle"
        root.panelDismissed()
    }

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.large
    implicitHeight: 360
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    CommandJson {
        id: prefsFetch
        autoStart: false
        interval: 0
        onResultChanged: {
            if (result && result.ok && result.data && result.data.prefs)
                root.applyPrefs(result.data.prefs)
        }
    }

    CommandJson {
        id: infoFetch
        autoStart: false
        interval: 0
        onResultChanged: {
            if (!result)
                return
            if (result.ok && result.data
                    && String(result.data.url ?? "") === root.pendingUrl) {
                root.info = result.data
                root.phase = "ready"
            } else if (!result.ok
                    && String(result.data?.url ?? "") === root.pendingUrl) {
                root.loadError = String(result.error ?? "Falha ao ler o link.")
                root.phase = "error"
            }
        }
    }

    CommandJson {
        id: startRun
        autoStart: false
        interval: 0
        onResultChanged: {
            if (!result)
                return
            if (result.ok && result.data && result.data.job_id) {
                DownloadState.trackJob(String(result.data.job_id))
                root.doneRequested()
                root.visible = false
                root.phase = "idle"
            } else {
                root.startError = String(result.error ?? "Falha ao iniciar.")
                root.phase = "ready"
            }
        }
    }

    PopupCard {
        anchors.fill: parent
        theme: root.theme
        opened: root.visible

        Keys.onUpPressed: root.focusIndex = Math.max(0, root.focusIndex - 1)
        Keys.onDownPressed: root.focusIndex = Math.min(root.rowCount - 1, root.focusIndex + 1)
        Keys.onReturnPressed: root.cycleRow(root.focusIndex)
        Keys.onEnterPressed: root.cycleRow(root.focusIndex)
        Keys.onEscapePressed: root.close()

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.outer
            spacing: root.theme.spacingTokens.sm

            PopupHeader {
                width: parent.width
                theme: root.theme
                parentAnchored: false
                leadingIcon: "󰇚"
                title: root.pendingMode === "audio" ? "Baixar áudio" : "Baixar vídeo"
                subtitle: root.pendingUrl
            }

            // Metadata hero.
            Row {
                width: parent.width
                spacing: root.theme.spacingTokens.md
                visible: root.phase === "ready" || root.phase === "starting"

                Image {
                    width: 120
                    height: 68
                    fillMode: Image.PreserveAspectCrop
                    source: String(root.info?.thumbnail ?? "")
                    visible: String(root.info?.thumbnail ?? "").length > 0
                }

                Column {
                    width: parent.width - (String(root.info?.thumbnail ?? "").length > 0 ? 120 + parent.spacing : 0)
                    spacing: root.theme.spacingTokens.micro

                    Text {
                        width: parent.width
                        text: String(root.info?.title ?? "")
                        color: root.theme.foreground
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        text: String(root.info?.duration_str ?? "")
                        color: root.theme.surfaceVariantForeground
                        font.pixelSize: root.theme.typeTokens.meta
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.phase === "loading"
                text: "Lendo link…"
                color: root.theme.surfaceVariantForeground
                font.pixelSize: root.theme.typeTokens.body
            }

            Text {
                width: parent.width
                visible: root.phase === "error"
                text: root.loadError
                color: root.theme.red
                font.pixelSize: root.theme.typeTokens.body
                wrapMode: Text.Wrap
            }

            // Option rows.
            Repeater {
                model: root.phase === "ready" || root.phase === "starting" ? root.rowCount : 0

                PopupListRow {
                    id: optionRow
                    required property int index
                    theme: root.theme
                    active: root.focusIndex === index
                    title: {
                        const audio = root.pendingMode === "audio"
                        const row = audio ? index + 1 : index
                        if (row === 0)
                            return "Qualidade"
                        if (row === 1)
                            return "Formato"
                        if (row === 2)
                            return "Destino"
                        return root.phase === "starting" ? "Iniciando…" : "Confirmar download"
                    }
                    subtitle: {
                        const audio = root.pendingMode === "audio"
                        const row = audio ? index + 1 : index
                        if (row === 0)
                            return root.pickedQuality
                        if (row === 1)
                            return root.pickedFormat
                        if (row === 2)
                            return root.pickedDest
                        return root.pendingMode === "audio" ? "Extrair áudio" : "Baixar vídeo"
                    }
                    leadingIcon: {
                        const audio = root.pendingMode === "audio"
                        const row = audio ? index + 1 : index
                        if (row === 3)
                            return "󰄬"
                        return "󰒓"
                    }

                    interactionHandlers: TapHandler {
                        onTapped: root.cycleRow(optionRow.index)
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.startError.length > 0
                text: root.startError
                color: root.theme.red
                font.pixelSize: root.theme.typeTokens.meta
                wrapMode: Text.Wrap
            }
        }
    }
}
