import QtQuick
import Quickshell
import qs.services

// Etapa 1 do fatiamento do Spotlight: construção das ações de `:`.
// O Spotlight continua dono da janela, da consulta, da filtragem,
// da seleção, da execução e dos atalhos; este módulo só monta os itens.
QtObject {
    id: root

    required property var palette

    readonly property color cPink: palette.pink
    readonly property color cYellow: palette.yellow
    readonly property color cGreen: palette.green
    readonly property color cCyan: palette.cyan
    readonly property color cOrange: palette.orange
    readonly property color cRed: palette.red
    readonly property color cSecondary: palette.offWhite

    function configCategories() {
        const themeName = ThemeState.currentPalette?.name ?? ThemeState.currentTheme
        const nlStatus = NightLightState.nightLightEnabled
            ? (NightLightState.active ? "Ativa (" + NightLightState.currentTemp + "K)" : "Automática (Dia)")
            : "Desativada"
        const pLabel = PowerProfileState.activeLabel ?? "Equilibrado"
        const idleStatus = IdleState.inhibited ? "Inibição ativa" : "Padrão"

        return [
            {
                kind: "config_category",
                prefix: ":tema ",
                title: "Aparência e temas",
                subtitle: "Tema atual: " + themeName + " · Enter para ver temas",
                icon: "󰔎",
                tablerIcon: "palette",
                color: root.cPink
            },
            {
                kind: "config_category",
                prefix: ":tela ",
                title: "Tela e energia",
                subtitle: "Luz noturna: " + nlStatus + " · " + pLabel + " · " + idleStatus,
                icon: "󰛨",
                tablerIcon: "bar-sun",
                color: root.cYellow
            },
            {
                kind: "config_category",
                prefix: ":conexoes ",
                title: "Conexões e áudio",
                subtitle: "Wi-Fi, Bluetooth e mixer de áudio · Enter para opções",
                icon: "󰤨",
                tablerIcon: "bar-wifi",
                color: root.cCyan
            },
            {
                kind: "config_category",
                prefix: ":captura ",
                title: "Captura e compartilhamento",
                subtitle: "Captura de tela, gravação e leitura de QR code",
                icon: "󰄡",
                tablerIcon: "crop",
                color: root.cCyan
            },
            {
                kind: "config_category",
                prefix: ":sistema ",
                title: "Sistema e sessão",
                subtitle: "Informações e monitoramento do sistema, bloqueio e opções de energia",
                icon: "󰒓",
                tablerIcon: "bar-settings",
                color: root.cOrange
            }
        ]
    }

    function themeActions() {
        const wpPickItem = {
            kind: "wp_pick",
            title: "Escolher papel de parede…",
            subtitle: "Abrir o seletor e atualizar as cores do tema",
            icon: "󰈔",
            tablerIcon: "photo",
            color: root.cPink
        }
        const wpRandomItem = {
            kind: "wp_random",
            title: "Papel de parede aleatório",
            subtitle: "Escolher uma imagem e atualizar o tema",
            icon: "",
            tablerIcon: "bar-refresh",
            color: root.cGreen
        }
        const cycleItem = {
            kind: "theme_cycle",
            title: "Usar próximo tema",
            subtitle: "Avançar na lista de temas (atual: " + (ThemeState.currentPalette?.name ?? ThemeState.currentTheme) + ")",
            icon: "󰔎",
            tablerIcon: "palette",
            color: root.cPink
        }
        const sortedList = (ThemeState.themesList ?? []).slice().sort((a, b) => (a.name ?? "").localeCompare(b.name ?? "", undefined, { sensitivity: "base" }))
        const themeList = sortedList.map(t => {
            const isCurrent = (t.id === ThemeState.currentTheme)
            let sub = "Tema " + (t.category === "light" ? "claro" : "escuro")
            if (isCurrent) {
                const adapters = ThemeState.syncedAdapters ?? {}
                const kitty = adapters.kitty ? "Kitty ✓" : "Kitty –"
                const hl = adapters.hyprland ? "Hyprland ✓" : "Hyprland –"
                const lk = adapters.hyprlock ? "Hyprlock ✓" : "Hyprlock –"
                sub += " (ativo · Shell ✓ · " + kitty + " · " + hl + " · " + lk + ")"
            } else {
                sub += " · Enter para aplicar em todos os aplicativos"
            }
            return {
                kind: "theme_select",
                themeId: t.id,
                accent: t.accent,
                title: t.name + (isCurrent ? "  ✓" : ""),
                subtitle: sub,
                icon: "󰔎",
                tablerIcon: "palette",
                color: t.accent ?? root.cPink
            }
        })
        return [wpPickItem, wpRandomItem, cycleItem].concat(themeList)
    }

    function nightlightActions() {
        return [
            {
                kind: "nightlight_toggle",
                title: NightLightState.nightLightEnabled ? "Desativar luz noturna" : "Ativar luz noturna",
                subtitle: NightLightState.nightLightEnabled
                    ? "Luz noturna ativa · " + (NightLightState.city.length > 0 ? NightLightState.city : "Solar") + " (" + NightLightState.currentTemp + "K)"
                    : "Luz noturna desligada · Horário solar de " + (NightLightState.city.length > 0 ? NightLightState.city : "clima") + " (Pôr: " + NightLightState.sunset + ")",
                icon: NightLightState.nightLightEnabled ? "󰛨" : "󰛩",
                tablerIcon: "bar-moon",
                color: root.cYellow
            },
            {
                kind: "nightlight_set",
                val: true,
                title: "Ativar luz noturna agora",
                subtitle: "Ativar o filtro sem esperar pelo horário automático",
                icon: "󰛨",
                tablerIcon: "bar-moon",
                color: root.cYellow
            },
            {
                kind: "nightlight_set",
                val: false,
                title: "Desativar luz noturna",
                subtitle: "Desativar o filtro de temperatura",
                icon: "󰛩",
                tablerIcon: "bar-sun",
                color: root.cYellow
            }
        ]
    }

    function energyActions() {
        const curProfile = PowerProfileState.activeProfile
        return [
            {
                kind: "idle_toggle",
                title: IdleState.inhibited ? "Permitir suspensão" : "Inibir suspensão",
                subtitle: IdleState.inhibited
                    ? "A tela permanece ligada e o computador não suspende por inatividade"
                    : "Impedir que a tela apague ou o computador suspenda por inatividade",
                icon: IdleState.inhibited ? "󰅶" : "󰾪",
                tablerIcon: "bar-coffee",
                color: IdleState.inhibited ? root.cGreen : root.cSecondary
            },
            {
                kind: "power_profile",
                profile: "performance",
                title: "Desempenho" + (curProfile === "performance" ? "  ✓" : ""),
                subtitle: "Prioriza o desempenho e permite frequências mais altas" + (curProfile === "performance" ? " (ativo)" : ""),
                icon: "󰓅",
                tablerIcon: "bolt",
                color: root.cGreen
            },
            {
                kind: "power_profile",
                profile: "balanced",
                title: "Equilibrado" + (curProfile === "balanced" ? "  ✓" : ""),
                subtitle: "Equilíbrio entre desempenho e economia de energia" + (curProfile === "balanced" ? " (ativo)" : ""),
                icon: "󰾆",
                tablerIcon: "gauge",
                color: root.cGreen
            },
            {
                kind: "power_profile",
                profile: "power-saver",
                title: "Economia de energia" + (curProfile === "power-saver" ? "  ✓" : ""),
                subtitle: "Reduz o desempenho para economizar bateria" + (curProfile === "power-saver" ? " (ativo)" : ""),
                icon: "󰌪",
                tablerIcon: "leaf",
                color: root.cGreen
            },
            {
                kind: "power_profile",
                profile: "extra-low-power",
                title: "Ultra Eco" + (curProfile === "extra-low-power" ? "  ✓" : ""),
                subtitle: "Economia máxima (1,6 GHz e turbo desativado; automático ≤ 15%)" + (curProfile === "extra-low-power" ? " (ativo)" : ""),
                icon: "󰌪",
                tablerIcon: "leaf",
                color: root.cGreen
            }
        ]
    }

    function connectionActions() {
        return [
            {
                kind: "app_exec",
                command: ["blueberry"],
                title: "Dispositivos Bluetooth",
                subtitle: "Abrir painel de pareamento e conexões Bluetooth",
                icon: "󰂯",
                tablerIcon: "bluetooth",
                color: root.cCyan
            },
            {
                kind: "app_exec",
                command: ["pwvucontrol"],
                title: "Mixer de áudio",
                subtitle: "Ajustar entradas, saídas e canais de áudio",
                icon: "󰕾",
                tablerIcon: "bar-volume",
                color: root.cCyan
            }
        ]
    }

    function systemActionsList() {
        return [
            {
                kind: "system_info",
                title: "Informações do sistema",
                subtitle: "Resumo do sistema, hardware e ambiente gráfico",
                icon: "󰍹",
                tablerIcon: "device-desktop",
                color: root.cOrange
            },
            {
                kind: "restart_quickshell",
                title: "Reiniciar Quickshell",
                subtitle: "Recarregar a barra, os serviços e os popups",
                icon: "󰑓",
                tablerIcon: "bar-refresh",
                color: root.cOrange
            },
            {
                kind: "app_exec",
                command: [Quickshell.shellDir + "/scripts/open-terminal.sh", "--", "htop"],
                title: "Monitor do sistema",
                subtitle: "Abrir o htop no terminal padrão",
                icon: "󰍹",
                tablerIcon: "bar-cpu",
                color: root.cOrange
            }
        ]
    }

    function captureActions() {
        const items = [
            {
                kind: "system",
                title: "Captura de área",
                subtitle: "Selecionar uma região e copiar a imagem",
                icon: "󰹑",
                tablerIcon: "crop",
                color: root.cCyan,
                command: [Quickshell.shellDir + "/scripts/screenshot.sh", "area"]
            }
        ]
        if (ScreenRecordingState.recording) {
            const elapsed = ScreenRecordingState.elapsedText.length > 0
                ? ScreenRecordingState.elapsedText
                : "0:00"
            items.push({
                kind: "screen_recording_stop",
                title: "Parar gravação",
                subtitle: "Gravação em andamento (" + elapsed + ") · Enter para parar",
                icon: "󰓛",
                tablerIcon: "player-stop",
                color: root.cRed
            })
        } else {
            items.push(
                {
                    kind: "system",
                    title: "Gravar tela",
                    subtitle: "Capturar a tela inteira sem áudio",
                    icon: "󰕧",
                    tablerIcon: "bar-record",
                    color: root.cCyan,
                    command: ["python3", "-B", Quickshell.shellDir + "/scripts/screen-recording.py", "start", "screen"]
                },
                {
                    kind: "system",
                    title: "Gravar tela com áudio",
                    subtitle: "Capturar a tela inteira com áudio do sistema e microfone",
                    icon: "󰕾",
                    tablerIcon: "microphone",
                    color: root.cCyan,
                    command: ["python3", "-B", Quickshell.shellDir + "/scripts/screen-recording.py", "start", "screen", "--audio"]
                }
            )
        }
        items.push({
            kind: "system",
            title: "Ler QR code da tela",
            subtitle: "Selecionar uma região e copiar o código para a área de transferência",
            icon: "󰄡",
            tablerIcon: "network-qr",
            color: root.cCyan,
            command: [Quickshell.shellDir + "/scripts/scan-qr.sh"]
        })
        return items
    }

    function sessionActions() {
        return [
            {
                kind: "system",
                title: "Bloquear sessão",
                subtitle: "Bloquear a tela imediatamente",
                icon: "󰌾",
                tablerIcon: "bar-lock",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "lock"]
            },
            {
                kind: "system",
                title: "Suspender",
                subtitle: "Suspender o computador (dormir)",
                icon: "󰤄",
                tablerIcon: "bar-moon",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "suspend"]
            },
            {
                kind: "system",
                title: "Encerrar sessão",
                subtitle: "Fechar aplicativos e encerrar sessão gráfica",
                icon: "󰗼",
                tablerIcon: "logout",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "logout"]
            },
            {
                kind: "system",
                title: "Reiniciar computador",
                subtitle: "Reinicializar o sistema operacional",
                icon: "󰜉",
                tablerIcon: "bar-refresh",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "reboot"]
            },
            {
                kind: "system",
                title: "Desligar computador",
                subtitle: "Fechar aplicativos e desligar o computador",
                icon: "󰐥",
                tablerIcon: "power",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "poweroff"]
            }
        ]
    }

    function allSettingsActions() {
        return [].concat(
            themeActions(),
            nightlightActions(),
            energyActions(),
            connectionActions(),
            captureActions(),
            systemActionsList(),
            sessionActions()
        )
    }
}
