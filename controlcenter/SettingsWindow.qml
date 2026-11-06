// LEGADO: janela independente de configurações não montada no shell atual (substituída por bar/NotificationPopup.qml e launcher/Spotlight.qml).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

FloatingWindow {
    id: root

    required property var theme

    title: "Configurações"
    implicitWidth: 800
    implicitHeight: 560
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false

    property string currentTab: "wallpaper"
    readonly property string activeWallpaper: WallpaperState.activeWallpaper
    readonly property bool isWorking: WallpaperState.isWorking
    property string statusMessage: ""

    IpcHandler {
        target: "settings"

        function toggle() { root.visible = !root.visible }
        function open() { root.visible = true }
        function close() { root.visible = false }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    Connections {
        target: WallpaperState
        function onStatusMessageChanged() {
            if (WallpaperState.statusMessage.length > 0)
                root.statusMessage = WallpaperState.statusMessage
        }
        function onActionDone(ok) {
            if (ok)
                root.statusMessage = "Papel de parede atualizado!"
            statusTimer.restart()
        }
    }

    Timer {
        id: statusTimer
        interval: 3500
        repeat: false
        onTriggered: root.statusMessage = ""
    }

    function runWallpaperAction(action, arg) {
        if (action === "pick")
            WallpaperState.pickWallpaper()
        else if (action === "random")
            WallpaperState.randomWallpaper()
        else if (action === "apply")
            WallpaperState.applyWallpaper(arg)
    }

    PopupCard {
        id: windowCard
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: root.theme.spacingTokens.xl

            // ==========================================
            // HEADER BAR
            // ==========================================
            Row {
                width: parent.width
                height: 38
                spacing: root.theme.spacingTokens.xl

                Text {
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰒓"
                    color: root.theme.accent
                    font.family: root.theme.nerdFontFamily
                    font.pixelSize: root.theme.iconTokens.hero
                }

                Column {
                    width: parent.width - 24 - 12 - 32 - 12 - 32
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.theme.spacingTokens.tiny

                    Text {
                        text: "Configurações"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.titleLarge
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.statusMessage.length > 0
                              ? root.statusMessage
                              : (ThemeState.error.length > 0
                                 ? ThemeState.error
                                 : "Personalização visual e preferências do desktop shell")
                        color: root.statusMessage.length > 0
                               ? root.theme.accent
                               : (ThemeState.error.length > 0 ? root.theme.red : root.theme.grey)
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                    }
                }

                // Botão Voltar ao Spotlight
                Rectangle {
                    width: 32
                    height: 32
                    radius: root.theme.radiusSm
                    anchors.verticalCenter: parent.verticalCenter
                    color: spotHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                    border.width: 1
                    border.color: spotHover.hovered ? root.theme.borderRegular : root.theme.borderSubtle

                    Text {
                        anchors.centerIn: parent
                        text: "󰍉"
                        color: spotHover.hovered ? root.theme.accent : root.theme.grey
                        font.family: root.theme.nerdFontFamily
                        font.pixelSize: root.theme.iconTokens.md
                    }

                    HoverHandler { id: spotHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.visible = false
                            Quickshell.execDetached(["quickshell", "ipc", "call", "spotlight", "toggle"])
                        }
                    }
                }

                // Botão Fechar
                CloseButton {
                    buttonSize: 32
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    onClicked: root.visible = false
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            // ==========================================
            // CORPO PRINCIPAL (SIDEBAR + CONTEÚDO)
            // ==========================================
            Row {
                width: parent.width
                height: parent.height - 52
                spacing: root.theme.spacingTokens.xxl

                // --- SIDEBAR DE NAVEGAÇÃO ---
                Column {
                    width: 190
                    height: parent.height
                    spacing: root.theme.spacingTokens.sm

                    // Botão 1: Wallpaper & Cores
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.theme.radiusMd
                        color: root.currentTab === "wallpaper" ? root.theme.glassActiveSurface : (navWpHover.hovered ? root.theme.glassHoverSurface : "transparent")
                        border.width: 1
                        border.color: root.currentTab === "wallpaper" ? root.theme.primary : (navWpHover.hovered ? root.theme.borderRegular : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.theme.popupInsets.large
                            spacing: root.theme.spacingTokens.lg

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: root.currentTab === "wallpaper" ? root.theme.primary : root.theme.offWhite
                                font.family: root.theme.nerdFontFamily
                                font.pixelSize: root.theme.iconTokens.lg
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Aparência"
                                color: root.currentTab === "wallpaper" ? root.theme.foreground : root.theme.offWhite
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                font.weight: root.currentTab === "wallpaper" ? Font.Bold : Font.Normal
                            }
                        }

                        HoverHandler { id: navWpHover }
                        TapHandler { onTapped: root.currentTab = "wallpaper" }
                    }

                    // Botão 2: Barra & Layout
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.theme.radiusMd
                        color: root.currentTab === "bar" ? root.theme.glassActiveSurface : (navBarHover.hovered ? root.theme.glassHoverSurface : "transparent")
                        border.width: 1
                        border.color: root.currentTab === "bar" ? root.theme.primary : (navBarHover.hovered ? root.theme.borderRegular : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.theme.popupInsets.large
                            spacing: root.theme.spacingTokens.lg

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰄯"
                                color: root.currentTab === "bar" ? root.theme.primary : root.theme.offWhite
                                font.family: root.theme.nerdFontFamily
                                font.pixelSize: root.theme.iconTokens.lg
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Barra e layout"
                                color: root.currentTab === "bar" ? root.theme.foreground : root.theme.offWhite
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                font.weight: root.currentTab === "bar" ? Font.Bold : Font.Normal
                            }
                        }

                        HoverHandler { id: navBarHover }
                        TapHandler { onTapped: root.currentTab = "bar" }
                    }

                    // Botão 3: Adaptadores & Sistema
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.theme.radiusMd
                        color: root.currentTab === "system" ? root.theme.glassActiveSurface : (navSysHover.hovered ? root.theme.glassHoverSurface : "transparent")
                        border.width: 1
                        border.color: root.currentTab === "system" ? root.theme.primary : (navSysHover.hovered ? root.theme.borderRegular : "transparent")

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.theme.popupInsets.large
                            spacing: root.theme.spacingTokens.lg

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰒓"
                                color: root.currentTab === "system" ? root.theme.primary : root.theme.offWhite
                                font.family: root.theme.nerdFontFamily
                                font.pixelSize: root.theme.iconTokens.lg
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Integrações"
                                color: root.currentTab === "system" ? root.theme.foreground : root.theme.offWhite
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                font.weight: root.currentTab === "system" ? Font.Bold : Font.Normal
                            }
                        }

                        HoverHandler { id: navSysHover }
                        TapHandler { onTapped: root.currentTab = "system" }
                    }
                }

                // Divisor vertical
                Rectangle {
                    width: 1
                    height: parent.height
                    color: root.theme.borderSubtle
                }

                // --- PAINEL DE CONTEÚDO ---
                Item {
                    width: parent.width - 190 - 1 - 14
                    height: parent.height

                    // TAB 1: WALLPAPER & CORES
                    Flickable {
                        id: wpFlickable
                        anchors.fill: parent
                        visible: root.currentTab === "wallpaper"
                        contentWidth: width
                        contentHeight: wpCol.implicitHeight + 20
                        clip: true

                        WheelKinetic { scrollTarget: wpFlickable }

                        Column {
                            id: wpCol
                            width: parent.width
                            spacing: root.theme.spacingTokens.xxl

                            // CARD: WALLPAPER ATUAL & AÇÕES
                            Rectangle {
                                width: parent.width
                                height: 160
                                radius: root.theme.radiusLg
                                color: root.theme.glassPanelSurface
                                border.width: 1
                                border.color: root.theme.glassBorderSubtle

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: root.theme.popupInsets.large
                                    spacing: root.theme.popupInsets.panel

                                    // Thumbnail do Wallpaper
                                    Rectangle {
                                        width: 230
                                        height: 136
                                        radius: root.theme.radiusMd
                                        clip: true
                                        color: root.theme.surface

                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: root.activeWallpaper ? ("file://" + root.activeWallpaper) : ("file://" + ShellPaths.currentWallpaper)
                                            cache: false
                                            asynchronous: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: root.theme.radiusMd
                                            color: "transparent"
                                            border.width: 1
                                            border.color: root.theme.glassBorder
                                        }
                                    }

                                    // Ações do Wallpaper
                                    Column {
                                        width: parent.width - 230 - 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: root.theme.spacingTokens.md

                                        Text {
                                            text: "Papel de parede ativo"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.title
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            width: parent.width
                                            elide: Text.ElideMiddle
                                            text: root.activeWallpaper ? root.activeWallpaper.split("/").pop() : "Papel de parede atual"
                                            color: root.theme.grey
                                            font.family: root.theme.monoFontFamily
                                            font.pixelSize: root.theme.typeTokens.body
                                        }

                                        Row {
                                            spacing: root.theme.spacingTokens.md

                                            // Botão: Escolher Arquivo
                                            Rectangle {
                                                width: 125
                                                height: 32
                                                radius: root.theme.radiusSm
                                                color: pickHover.hovered ? root.theme.glassHoverSurface : root.theme.primaryContainer
                                                border.width: 1
                                                border.color: root.theme.primary

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: root.theme.spacingTokens.sm
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "󰈔"
                                                        color: root.theme.primary
                                                        font.family: root.theme.nerdFontFamily
                                                        font.pixelSize: root.theme.iconTokens.mdPlus
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Escolher…"
                                                        color: root.theme.foreground
                                                        font.family: root.theme.fontFamily
                                                        font.pixelSize: root.theme.typeTokens.subtitle
                                                        font.weight: Font.Medium
                                                    }
                                                }

                                                HoverHandler { id: pickHover }
                                                TapHandler { onTapped: root.runWallpaperAction("pick") }
                                            }

                                            // Botão: Aleatório
                                            Rectangle {
                                                width: 100
                                                height: 32
                                                radius: root.theme.radiusSm
                                                color: randHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                                                border.width: 1
                                                border.color: root.theme.borderSubtle

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: root.theme.spacingTokens.sm
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: ""
                                                        color: root.theme.offWhite
                                                        font.family: root.theme.nerdFontFamily
                                                        font.pixelSize: root.theme.iconTokens.mdPlus
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Aleatório"
                                                        color: root.theme.offWhite
                                                        font.family: root.theme.fontFamily
                                                        font.pixelSize: root.theme.typeTokens.subtitle
                                                    }
                                                }

                                                HoverHandler { id: randHover }
                                                TapHandler { onTapped: root.runWallpaperAction("random") }
                                            }

                                            // Botão: Recarregar Paleta
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: root.theme.radiusSm
                                                color: syncHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                                                border.width: 1
                                                border.color: root.theme.borderSubtle

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰔎"
                                                    color: root.theme.accent
                                                    font.family: root.theme.nerdFontFamily
                                                    font.pixelSize: root.theme.iconTokens.lg
                                                }

                                                HoverHandler { id: syncHover }
                                                TapHandler { onTapped: Quickshell.execDetached(["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "update-wallpaper"]) }
                                            }
                                        }
                                    }
                                }
                            }

                            // SEÇÃO: MODO CLARO / ESCURO
                            Column {
                                width: parent.width
                                spacing: root.theme.spacingTokens.sm

                                Text {
                                    text: "Aparência Geral"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                    font.weight: Font.Bold
                                }

                                Row {
                                    spacing: root.theme.spacingTokens.md

                                    // Botão Escuro
                                    Rectangle {
                                        width: 120
                                        height: 34
                                        radius: root.theme.radiusSm
                                        color: !root.theme.isLight ? root.theme.glassActiveSurface : root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: !root.theme.isLight ? root.theme.primary : root.theme.borderSubtle

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: root.theme.spacingTokens.md
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰖔"
                                                color: !root.theme.isLight ? root.theme.primary : root.theme.offWhite
                                                font.family: root.theme.nerdFontFamily
                                                font.pixelSize: root.theme.iconTokens.lg
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Escuro"
                                                color: !root.theme.isLight ? root.theme.foreground : root.theme.offWhite
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.subtitle
                                                font.weight: !root.theme.isLight ? Font.Bold : Font.Normal
                                            }
                                        }

                                        HoverHandler { id: darkHover }
                                        TapHandler { onTapped: ThemeState.setTheme("chameleon") }
                                    }

                                    // Botão Claro
                                    Rectangle {
                                        width: 120
                                        height: 34
                                        radius: root.theme.radiusSm
                                        color: root.theme.isLight ? root.theme.glassActiveSurface : root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: root.theme.isLight ? root.theme.primary : root.theme.borderSubtle

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: root.theme.spacingTokens.md
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰖙"
                                                color: root.theme.isLight ? root.theme.primary : root.theme.offWhite
                                                font.family: root.theme.nerdFontFamily
                                                font.pixelSize: root.theme.iconTokens.lg
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Claro"
                                                color: root.theme.isLight ? root.theme.foreground : root.theme.offWhite
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.subtitle
                                                font.weight: root.theme.isLight ? Font.Bold : Font.Normal
                                            }
                                        }

                                        HoverHandler { id: lightHover }
                                        TapHandler { onTapped: ThemeState.setTheme("chameleon-light") }
                                    }
                                }
                            }

                            // Três aparências baseadas na mesma paleta Material.
                            Column {
                                width: parent.width
                                spacing: root.theme.spacingTokens.md
                                Text {
                                    text: "Chameleon (Material You)"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                    font.weight: Font.Bold
                                }
                                Flow {
                                    width: parent.width
                                    spacing: root.theme.spacingTokens.md
                                    Repeater {
                                        model: [
                                            { id: "chameleon", label: "Escuro" },
                                            { id: "chameleon-light", label: "Claro" },
                                            { id: "chameleon-oled", label: "OLED" }
                                        ]
                                        Rectangle {
                                            id: themeOptionDelegate
                                            required property var modelData
                                            readonly property bool selected: ThemeState.currentTheme === modelData.id
                                            width: 130
                                            height: 34
                                            radius: root.theme.radiusSm
                                            activeFocusOnTab: true
                                            color: selected ? root.theme.glassActiveSurface : (chipHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface)
                                            border.width: 1
                                            border.color: selected ? root.theme.primary : root.theme.borderSubtle
                                            Keys.onReturnPressed: ThemeState.setTheme(modelData.id)
                                            Keys.onEnterPressed: ThemeState.setTheme(modelData.id)
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: root.theme.spacingTokens.sm
                                                Rectangle {
                                                    width: 8
                                                    height: 8
                                                    radius: height / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: ThemeState.palettes[themeOptionDelegate.modelData.id]?.accent ?? root.theme.accent
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: themeOptionDelegate.modelData.label
                                                    color: themeOptionDelegate.selected ? root.theme.foreground : root.theme.offWhite
                                                    font.family: root.theme.fontFamily
                                                    font.pixelSize: root.theme.typeTokens.subtitle
                                                    font.weight: themeOptionDelegate.selected ? Font.Bold : Font.Normal
                                                }
                                            }
                                            HoverHandler { id: chipHover }
                                            TapHandler { onTapped: ThemeState.setTheme(themeOptionDelegate.modelData.id) }
                                        }
                                    }
                                }
                            }

                            // SEÇÃO: CATÁLOGO DE TEMAS ESTÁTICOS
                            Column {
                                width: parent.width
                                spacing: root.theme.spacingTokens.md

                                Text {
                                    text: "Temas Clássicos"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                    font.weight: Font.Bold
                                }

                                Flow {
                                    width: parent.width
                                    spacing: root.theme.spacingTokens.sm

                                    Repeater {
                                        model: ["catppuccin-mocha", "tokyo-night", "nord", "dracula",
                                                "everforest", "gruvbox", "rose-pine", "solarized-dark"]
                                            .map(id => ThemeState.themesList.find(theme => theme.id === id))
                                            .filter(theme => theme !== undefined)

                                        delegate: Rectangle {
                                            id: themeVariantDelegate
                                            required property var modelData
                                            width: 125
                                            height: 28
                                            radius: root.theme.radiusSm
                                            color: ThemeState.currentTheme === modelData.id ? root.theme.glassActiveSurface : (tHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface)
                                            border.width: 1
                                            border.color: ThemeState.currentTheme === modelData.id ? root.theme.primary : root.theme.borderSubtle

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: root.theme.spacingTokens.sm
                                                Rectangle {
                                                    width: 6
                                                    height: 6
                                                    radius: height / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: themeVariantDelegate.modelData.accent
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: themeVariantDelegate.modelData.name
                                                    color: ThemeState.currentTheme === themeVariantDelegate.modelData.id ? root.theme.foreground : root.theme.offWhite
                                                    font.family: root.theme.fontFamily
                                                    font.pixelSize: root.theme.typeTokens.body
                                                }
                                            }

                                            HoverHandler { id: tHover }
                                            TapHandler { onTapped: ThemeState.setTheme(themeVariantDelegate.modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 2: BARRA & LAYOUT
                    Column {
                        anchors.fill: parent
                        visible: root.currentTab === "bar"
                        spacing: root.theme.spacingTokens.xxl

                        Text {
                            text: "Barra superior e disposição"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.title
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            width: parent.width
                            height: 110
                            radius: root.theme.radiusLg
                            color: root.theme.glassPanelSurface
                            border.width: 1
                            border.color: root.theme.borderSubtle

                            Column {
                                anchors.fill: parent
                                anchors.margins: root.theme.popupInsets.outer
                                spacing: root.theme.spacingTokens.md

                                Text {
                                    text: "Posição da barra"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                    font.weight: Font.Medium
                                }

                                Row {
                                    spacing: root.theme.spacingTokens.md

                                    Rectangle {
                                        width: 100
                                        height: 32
                                        radius: root.theme.radiusSm
                                        color: root.theme.glassActiveSurface
                                        border.width: 1
                                        border.color: root.theme.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰁝 Superior"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.subtitle
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Rectangle {
                                        width: 100
                                        height: 32
                                        radius: root.theme.radiusSm
                                        color: root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: root.theme.borderSubtle

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰁅 Inferior"
                                            color: root.theme.grey
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.subtitle
                                        }
                                    }
                                }

                                Text {
                                    text: "Posição ativa: Topo com altura de 37px e margem de 3px"
                                    color: root.theme.grey
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.body
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 130
                            radius: root.theme.radiusLg
                            color: root.theme.glassPanelSurface
                            border.width: 1
                            border.color: root.theme.borderSubtle

                            Column {
                                anchors.fill: parent
                                anchors.margins: root.theme.popupInsets.outer
                                spacing: root.theme.spacingTokens.md

                                Text {
                                    text: "Estilo da barra"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                    font.weight: Font.Medium
                                }

                                Row {
                                    spacing: root.theme.spacingTokens.md

                                    Rectangle {
                                        width: 130
                                        height: 32
                                        radius: root.theme.radiusSm
                                        color: root.theme.glassActiveSurface
                                        border.width: 1
                                        border.color: root.theme.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰖲 Flutuante"
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.subtitle
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Rectangle {
                                        width: 130
                                        height: 32
                                        radius: root.theme.radiusSm
                                        color: root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: root.theme.borderSubtle

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄯 Largura total"
                                            color: root.theme.grey
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.subtitle
                                        }
                                    }
                                }

                                Text {
                                    text: "O estilo flutuante tem cantos arredondados e uma borda sutil."
                                    color: root.theme.grey
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.body
                                }
                            }
                        }
                    }

                    // TAB 3: INTEGRAÇÕES
                    Column {
                        anchors.fill: parent
                        visible: root.currentTab === "system"
                        spacing: root.theme.spacingTokens.xxl

                        Text {
                            text: "Sincronização de temas"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.title
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Ao mudar o tema ou o papel de parede, estas integrações são atualizadas:"
                            color: root.theme.grey
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.subtitle
                        }

                        Flow {
                            width: parent.width
                            spacing: root.theme.spacingTokens.md

                            Repeater {
                                model: [
                                    { name: "Quickshell", key: "quickshell", icon: "󰄯" },
                                    { name: "Kitty", key: "kitty", icon: "󰆍" },
                                    { name: "Hyprland", key: "hyprland", icon: "󰣇" },
                                    { name: "Hyprlock", key: "hyprlock", icon: "󰌾" },
                                    { name: "BTOP", key: "btop", icon: "󰄬" },
                                    { name: "Qt / Kvantum", key: "qt", icon: "󰟀" },
                                    { name: "GTK", key: "gtk", icon: "󰕰" },
                                    { name: "Mango", key: "mango", icon: "󰖯" }
                                ]

                                delegate: Rectangle {
                                    id: themeAdapterDelegate
                                    required property var modelData
                                    readonly property bool isSynced: Boolean(ThemeState.syncedAdapters[modelData.key])
                                    width: 160
                                    height: 48
                                    radius: root.theme.radiusMd
                                    color: root.theme.glassPanelSurface
                                    border.width: 1
                                    border.color: isSynced ? root.theme.green : root.theme.borderSubtle

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: root.theme.popupInsets.standard
                                        spacing: root.theme.spacingTokens.lg

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: themeAdapterDelegate.modelData.icon
                                            color: themeAdapterDelegate.isSynced ? root.theme.green : root.theme.grey
                                            font.family: root.theme.nerdFontFamily
                                            font.pixelSize: root.theme.iconTokens.xl
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: root.theme.spacingTokens.tiny

                                            Text {
                                                text: themeAdapterDelegate.modelData.name
                                                color: root.theme.foreground
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.subtitle
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                text: themeAdapterDelegate.isSynced ? "Sincronizado" : "Não sincronizado"
                                                color: themeAdapterDelegate.isSynced ? root.theme.green : root.theme.grey
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.meta
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 220
                            height: 36
                            radius: root.theme.radiusSm
                            color: syncAllHov.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                            border.width: 1
                            border.color: root.theme.glassBorderSubtle

                            Row {
                                anchors.centerIn: parent
                                spacing: root.theme.spacingTokens.md
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰑐"
                                    color: root.theme.accent
                                    font.family: root.theme.nerdFontFamily
                                    font.pixelSize: root.theme.iconTokens.lg
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Sincronizar novamente"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.typeTokens.subtitle
                                }
                            }

                            HoverHandler { id: syncAllHov }
                            TapHandler {
                                onTapped: {
                                    ThemeState.refresh()
                                    root.statusMessage = "Ressincronizando adaptadores..."
                                    statusTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
