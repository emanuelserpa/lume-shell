pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property var commandResult: ({ ok: false, data: ({}), error: "" })
    property bool opened: false

    signal closeRequested()

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.None
    // qmllint enable missing-type
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 760
    implicitHeight: 456
    color: "transparent"
    surfaceFormat.opaque: false
    visible: opened
    grabFocus: true

    readonly property var info: commandResult?.data ?? ({})
    readonly property bool hasData: Boolean(commandResult?.ok)
    readonly property var softwareRows: [
        { icon: "󰌢", label: "Kernel", value: info.kernel || "Indisponível" },
        { icon: "󰖯", label: "Compositor", value: [info.desktop, info.protocol].filter(Boolean).join(" · ") || "Indisponível" },
        { icon: "󰆍", label: "Shell", value: info.shell || "Indisponível" },
        { icon: "󰆍", label: "Terminal", value: info.terminal || "Indisponível" },
        { icon: "󰏖", label: "Pacotes", value: packageSummary(info.packages) }
    ]
    readonly property var hardwareRows: [
        { icon: "󰍛", label: "Processador", value: cpuSummary(info) },
        { icon: "󰢮", label: "Gráficos", value: gpuSummary(info.gpu) },
        { icon: "󰘚", label: "Memória", value: byteSummary(info.memory?.used, info.memory?.total) },
        { icon: "󰋊", label: "Disco do sistema", value: byteSummary(info.disk?.used, info.disk?.total) },
        { icon: "󰍹", label: "Tela", value: displaySummary(info.display) }
    ]

    function packageSummary(packages) {
        if (!packages)
            return "Indisponível"
        const parts = []
        if (Number(packages.pacman) > 0) parts.push("󰮯 " + packages.pacman)
        if (Number(packages.flatpak) > 0) parts.push(" " + packages.flatpak)
        if (Number(packages.brew) > 0) parts.push("󰡩 " + packages.brew)
        if (Number(packages.appimage) > 0) parts.push(" AppImage " + packages.appimage)
        return parts.length > 0 ? parts.join("   ") : (Number(packages.total) + " instalados")
    }

    function cpuSummary(value) {
        const name = String(value?.cpu ?? "Indisponível")
        const cores = Number(value?.cpuCores ?? 0)
        const threads = Number(value?.cpuThreads ?? 0)
        return cores > 0 ? name + " · " + cores + "C/" + threads + "T" : name
    }

    function gpuSummary(gpus) {
        if (!Array.isArray(gpus) || gpus.length === 0)
            return "Indisponível"
        return gpus.map(gpu => String(gpu.name ?? "")).filter(Boolean).join(" · ")
    }

    function displaySummary(display) {
        if (!display)
            return "Indisponível"
        const resolution = Number(display.width) > 0 && Number(display.height) > 0
            ? " · " + display.width + " × " + display.height
            : ""
        return String(display.name || "Display") + resolution
    }

    function byteSummary(used, total) {
        const usedBytes = Number(used ?? 0)
        const totalBytes = Number(total ?? 0)
        if (totalBytes <= 0)
            return "Indisponível"
        return formatBytes(usedBytes) + " / " + formatBytes(totalBytes)
    }

    function formatBytes(value) {
        let size = Math.max(0, Number(value ?? 0))
        if (size < 1024)
            return Math.round(size) + " B"
        size /= 1024
        if (size < 1024)
            return size.toFixed(1) + " KiB"
        size /= 1024
        if (size < 1024)
            return size.toFixed(1) + " MiB"
        size /= 1024
        if (size < 1024)
            return size.toFixed(1) + " GiB"
        size /= 1024
        return size.toFixed(1) + " TiB"
    }

    onVisibleChanged: {
        if (visible)
            card.forceActiveFocus()
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        Keys.onEscapePressed: root.closeRequested()

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.large
            spacing: root.theme.spacingTokens.md

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 42
                horizontalInset: 0
                topInset: 0
                title: root.hasData ? String(root.info.os ?? "Sistema") : "Informações do sistema"
                subtitle: root.hasData
                    ? [root.info.host, root.info.architecture, root.formatUptime(root.info.uptimeSeconds)].filter(Boolean).join(" · ")
                    : "Resumo do hardware e do ambiente gráfico"
                leadingIcon: "󰌽"
                leadingIconColor: root.theme.primary
                iconBoxColor: root.theme.glassCardSurface
                iconBoxSize: 38
                iconPixelSize: root.theme.iconTokens.xl
                titlePixelSize: root.theme.typeTokens.title
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            Row {
                width: parent.width
                height: parent.height - 58
                spacing: root.theme.spacingTokens.lg

                Column {
                    width: 246
                    height: parent.height
                    spacing: root.theme.spacingTokens.sm

                    Rectangle {
                        width: 72
                        height: 72
                        radius: root.theme.radiusLg
                        color: root.theme.glassCardSurface
                        border.width: 1
                        border.color: root.theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "󰌽"
                            color: root.theme.primary
                            font.family: root.theme.nerdFontFamily
                            font.pixelSize: 42
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.hasData ? String(root.info.os ?? "Linux") : "Sistema indisponível"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.subtitle
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
                        text: root.hasData
                            ? String(root.commandResult.error ?? "")
                            : String(root.commandResult?.error ?? "Não foi possível consultar o Fastfetch.")
                        visible: !root.hasData
                        color: root.theme.error
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.caption
                        wrapMode: Text.Wrap
                    }

                    Text {
                        text: "PACOTES"
                        color: root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.caption
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        topPadding: root.theme.spacingTokens.sm
                    }

                    Text {
                        width: parent.width
                        text: root.packageSummary(root.info.packages)
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: Number(root.info.battery?.capacity ?? 0) > 0
                        width: parent.width
                        text: "󰁹  " + Number(root.info.battery?.capacity ?? 0) + "%" + (root.info.battery?.status ? " · " + root.info.battery.status : "")
                        color: root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.caption
                    }

                    Item { width: 1; height: 1 }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: root.theme.borderSubtle
                }

                Row {
                    width: parent.width - 246 - root.theme.spacingTokens.lg - 1 - root.theme.spacingTokens.lg
                    height: parent.height
                    spacing: root.theme.spacingTokens.md

                    Column {
                        width: (parent.width - root.theme.spacingTokens.md) / 2
                        height: parent.height
                        spacing: root.theme.spacingTokens.xs

                        Text {
                            text: "SOFTWARE"
                            color: root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.caption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }

                        Repeater {
                            model: root.softwareRows
                            delegate: PopupListRow {
                                required property var modelData
                                theme: root.theme
                                width: parent.width
                                rowHeight: 52
                                cornerRadius: root.theme.radiusSm
                                idleColor: "transparent"
                                idleBorderWidth: 0
                                hoverEnabled: false
                                leadingIcon: modelData.icon
                                leadingIconColor: root.theme.surfaceVariantForeground
                                leadingIconPixelSize: root.theme.iconTokens.md
                                title: modelData.label
                                subtitle: modelData.value
                                titlePixelSize: root.theme.typeTokens.caption
                                titleWeight: Font.Medium
                                subtitlePixelSize: root.theme.typeTokens.caption
                            }
                        }
                    }

                    Column {
                        width: (parent.width - root.theme.spacingTokens.md) / 2
                        height: parent.height
                        spacing: root.theme.spacingTokens.xs

                        Text {
                            text: "HARDWARE"
                            color: root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.caption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }

                        Repeater {
                            model: root.hardwareRows
                            delegate: PopupListRow {
                                required property var modelData
                                theme: root.theme
                                width: parent.width
                                rowHeight: 52
                                cornerRadius: root.theme.radiusSm
                                idleColor: "transparent"
                                idleBorderWidth: 0
                                hoverEnabled: false
                                leadingIcon: modelData.icon
                                leadingIconColor: root.theme.primary
                                leadingIconPixelSize: root.theme.iconTokens.md
                                title: modelData.label
                                subtitle: modelData.value
                                titlePixelSize: root.theme.typeTokens.caption
                                titleWeight: Font.Medium
                                subtitlePixelSize: root.theme.typeTokens.caption
                            }
                        }
                    }
                }
            }
        }
    }

    function formatUptime(seconds) {
        let remaining = Math.max(0, Number(seconds ?? 0))
        const days = Math.floor(remaining / 86400)
        remaining %= 86400
        const hours = Math.floor(remaining / 3600)
        const minutes = Math.floor((remaining % 3600) / 60)
        const parts = []
        if (days) parts.push(days + "d")
        if (hours) parts.push(hours + "h")
        parts.push(minutes + "min")
        return parts.join(" ")
    }
}
