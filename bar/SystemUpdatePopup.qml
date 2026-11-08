import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var repoData: ({})
    property var aurData: ({})
    property var flatpakData: ({})
    property var brewData: ({})
    property var appImageData: ({})
    property bool showPackages: false
    property bool updateRunning: false
    property string updateMessage: ""
    property bool updateSucceeded: false
    property int updateStage: 0
    property int updateStageCount: 0
    property int updateProgress: -1
    property string logActionError: ""

    signal refreshRequested()
    signal updateRequested(string backend)

    CommandAction {
        id: openLogAction
        baseCommand: ["python3", "-B", Quickshell.shellDir + "/scripts/update-log.py"]
        fallbackError: "Não foi possível abrir o log da atualização."
        onSucceeded: root.logActionError = ""
        onFailed: root.logActionError = "Não foi possível abrir o log: " + error
    }

    readonly property int repoCount: Number(repoData?.count ?? 0)
    readonly property int aurCount: Number(aurData?.count ?? 0)
    readonly property int flatpakCount: Number(flatpakData?.count ?? 0)
    readonly property int brewCount: Number(brewData?.count ?? 0)
    readonly property int appImageCount: Number(appImageData?.count ?? 0)
    readonly property int totalCount: repoCount + aurCount + flatpakCount + brewCount + appImageCount

    readonly property var packageRows: {
        const rows = []
        const append = (label, accent, data) => {
            const items = data?.items ?? []
            for (let i = 0; i < items.length; i++) {
                rows.push({
                    "backend": label,
                    "accent": accent,
                    "text": String(items[i] ?? "")
                })
            }
        }
        append("Repo", theme.primary, repoData)
        append("AUR", theme.pink, aurData)
        append("Flatpak", theme.cyan, flatpakData)
        append("Brew", theme.orange, brewData)
        append("AppImage", theme.orange, appImageData)
        return rows
    }

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.smallPlus
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 326
    implicitHeight: contentColumn.implicitHeight
        + root.theme.popupInsets.standard * 2

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus()
            if (!root.updateRunning)
                root.refreshRequested()
        }
    }

    function statusText(data, count) {
        const status = String(data?.status ?? "")
        if (status === "timeout") return "timeout"
        if (status === "error") return "erro"
        if (count === 0) return "ok"
        return String(count)
    }

    function statusColor(data, count, accent) {
        const status = String(data?.status ?? "")
        if (status === "timeout") return theme.yellow
        if (status === "error") return theme.red
        if (count === 0) return theme.green
        return accent
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Keys.onEscapePressed: root.visible = false

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.standard
            spacing: root.theme.spacingTokens.smPlus

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 30
                horizontalInset: 0
                topInset: 0
                leadingTablerIcon: "bar-refresh"
                iconBoxSize: 28
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lgPlus
                contentGap: root.theme.spacingTokens.smPlus
                actionSpacing: 6
                title: "Atualizações"
                titlePixelSize: root.theme.typeTokens.titleMedium
                titleWeight: Font.Bold

                PopupIconButton {
                    id: refreshButton
                    width: 28
                    height: 26
                    radius: root.theme.radiusSm
                    theme: root.theme
                    tablerIcon: "bar-refresh"
                    iconPixelSize: root.theme.iconTokens.md
                    normalBackground: root.theme.glassCardSurface
                    hoverBackground: root.theme.glassHoverSurface
                    normalForeground: root.theme.primary
                    hoverForeground: root.theme.primary
                    enabled: !root.updateRunning
                    onClicked: root.refreshRequested()
                }
            }

            Text {
                width: parent.width
                text: root.totalCount === 0
                      ? "Tudo atualizado"
                      : root.totalCount + " atualizações disponíveis"
                color: root.totalCount === 0
                       ? root.theme.green
                       : root.theme.offWhite
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.subtitle
            }

            Row {
                width: parent.width
                height: 22
                spacing: root.theme.spacingTokens.xs
                visible: root.updateMessage.length > 0

                TablerIcon {
                    id: updateStatusIcon
                    width: root.updateSucceeded && !root.updateRunning
                           ? root.theme.iconTokens.lg : root.theme.iconTokens.md
                    height: width
                    iconName: root.updateRunning ? "bar-refresh" : (root.updateSucceeded ? "circle-check" : "close")
                    iconColor: root.updateRunning ? root.theme.primary
                           : (root.updateSucceeded ? root.theme.green : root.theme.red)
                    anchors.verticalCenter: parent.verticalCenter

                    RotationAnimation on rotation {
                        running: root.updateRunning
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }

                Text {
                    width: parent.width - root.theme.spacingTokens.xs - 20
                    text: root.updateMessage
                    color: root.updateRunning ? root.theme.primary
                           : (root.updateSucceeded ? root.theme.green : root.theme.red)
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs
                visible: root.updateRunning && root.updateStageCount > 0

                Text {
                    width: parent.width
                    text: "Etapa " + root.updateStage + " de " + root.updateStageCount
                    color: root.theme.offWhite
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: height / 2
                    color: root.theme.surfaceVariant
                    clip: true

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1,
                            root.updateProgress >= 0
                                ? ((root.updateStage - 1 + root.updateProgress / 100)
                                   / root.updateStageCount)
                                : (root.updateStage / root.updateStageCount)))
                        height: parent.height
                        radius: parent.radius
                        color: root.theme.primary

                        Behavior on width {
                            enabled: root.theme.qmlAnimationsEnabled
                            NumberAnimation {
                                duration: root.theme.motionMedium
                                easing.type: root.theme.motionEasing
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: root.theme.radiusSm
                visible: root.updateRunning || root.updateMessage.length > 0
                color: progressLogHover.hovered
                       ? root.theme.glassHoverSurface
                       : root.theme.glassCardSurface
                border.width: 1
                border.color: root.theme.borderSubtle

                Row {
                    anchors.centerIn: parent
                    spacing: root.theme.spacingTokens.xs

                    TablerIcon {
                        width: root.theme.iconTokens.md
                        height: root.theme.iconTokens.md
                        iconName: "bar-terminal"
                        iconColor: root.theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.updateRunning ? "Ver progresso no terminal" : "Abrir log da atualização"
                        color: root.theme.primary
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: progressLogHover }
                TapHandler {
                    enabled: !openLogAction.busy
                    onTapped: openLogAction.run(["open"])
                }
            }

            Text {
                width: parent.width
                visible: root.logActionError.length > 0
                text: root.logActionError
                color: root.theme.error
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                wrapMode: Text.Wrap
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.outlineVariant
            }

            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                UpdateBackendRow {
                    width: parent.width
                    theme: root.theme
                    tablerIcon: "package"
                    title: "Repositórios"
                    subtitle: "Repositórios oficiais"
                    accentColor: root.theme.primary
                    statusText: root.statusText(root.repoData, root.repoCount)
                    statusColor: root.statusColor(root.repoData, root.repoCount, root.theme.primary)
                    actionEnabled: !root.updateRunning
                    onRunRequested: root.updateRequested("repo")
                }

                UpdateBackendRow {
                    width: parent.width
                    theme: root.theme
                    tablerIcon: "bar-code"
                    title: "AUR"
                    subtitle: String(root.aurData?.status ?? "") === "timeout"
                              ? "consulta expirou — pode tentar de novo"
                              : "isolado dos repositórios"
                    accentColor: root.theme.pink
                    statusText: root.statusText(root.aurData, root.aurCount)
                    statusColor: root.statusColor(root.aurData, root.aurCount, root.theme.pink)
                    actionEnabled: !root.updateRunning
                    onRunRequested: root.updateRequested("aur")
                }

                UpdateBackendRow {
                    width: parent.width
                    theme: root.theme
                    tablerIcon: "package"
                    title: "Flatpak"
                    subtitle: "Aplicativos e runtimes"
                    accentColor: root.theme.cyan
                    statusText: root.statusText(root.flatpakData, root.flatpakCount)
                    statusColor: root.statusColor(root.flatpakData, root.flatpakCount, root.theme.cyan)
                    actionEnabled: !root.updateRunning
                    onRunRequested: root.updateRequested("flatpak")
                }

                UpdateBackendRow {
                    width: parent.width
                    theme: root.theme
                    tablerIcon: "bar-coffee"
                    title: "Homebrew"
                    subtitle: "Pacotes Homebrew"
                    accentColor: root.theme.orange
                    statusText: root.statusText(root.brewData, root.brewCount)
                    statusColor: root.statusColor(root.brewData, root.brewCount, root.theme.orange)
                    actionEnabled: !root.updateRunning
                    onRunRequested: root.updateRequested("brew")
                }

                UpdateBackendRow {
                    width: parent.width
                    theme: root.theme
                    tablerIcon: "bar-file"
                    title: "AppImages"
                    subtitle: "Gear Lever"
                    accentColor: root.theme.orange
                    statusText: root.statusText(root.appImageData, root.appImageCount)
                    statusColor: root.statusColor(root.appImageData, root.appImageCount, root.theme.orange)
                    actionEnabled: !root.updateRunning
                    onRunRequested: root.updateRequested("appimage")
                }
            }

            Row {
                width: parent.width
                height: 30
                spacing: root.theme.spacingTokens.smPlus

                Rectangle {
                    width: (parent.width - 7) * 0.42
                    height: parent.height
                    radius: root.theme.radiusSm
                    color: packagesHover.hovered
                           ? root.theme.glassHoverSurface
                           : root.theme.glassCardSurface
                    border.width: 1
                    border.color: packagesHover.hovered
                                  ? root.theme.borderRegular
                                  : root.theme.borderSubtle

                    Text {
                        anchors.centerIn: parent
                        text: root.showPackages ? "Ocultar pacotes" : "Ver pacotes"
                        color: root.theme.offWhite
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                    }

                    HoverHandler { id: packagesHover }
                    TapHandler { onTapped: root.showPackages = !root.showPackages }
                }

                Rectangle {
                    width: parent.width - ((parent.width - 7) * 0.42) - 7
                    height: parent.height
                    radius: root.theme.radiusSm
                    color: updateAllHover.hovered
                           ? root.theme.withAlpha(root.theme.primary, 0.26)
                           : root.theme.withAlpha(root.theme.primary, 0.14)
                    opacity: root.updateRunning ? 0.45 : 1
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.primary, 0.55)

                    Text {
                        anchors.centerIn: parent
                        text: "Atualizar tudo"
                        color: root.theme.primary
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.Bold
                    }

                    HoverHandler { id: updateAllHover }
                    TapHandler {
                        enabled: !root.updateRunning
                        onTapped: root.updateRequested("all")
                    }
                }
            }

            Item {
                width: parent.width
                height: root.showPackages ? 143 : 0
                visible: root.showPackages

                EmptyState {
                    anchors.centerIn: parent
                    visible: root.packageRows.length === 0
                    theme: root.theme
                    title: "Nenhum pacote pendente."
                    titleColor: root.theme.surfaceVariantForeground
                    titleSize: root.theme.typeTokens.body
                }

                ListView {
                    id: packageList
                    anchors.fill: parent
                    visible: root.packageRows.length > 0
                    model: root.packageRows
                    spacing: root.theme.spacingTokens.tight
                    clip: true

                    WheelKinetic { scrollTarget: packageList }

                    delegate: Row {
                        required property var modelData
                        width: ListView.view.width
                        height: 25
                        spacing: root.theme.spacingTokens.sm

                        Rectangle {
                            width: 4
                            height: 4
                            radius: height / 2
                            color: modelData.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: 50
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.backend
                            color: modelData.accent
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width - 60
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: root.theme.offWhite
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
