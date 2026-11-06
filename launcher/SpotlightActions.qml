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
                color: root.cPink
            },
            {
                kind: "config_category",
                prefix: ":tela ",
                title: "Tela e energia",
                subtitle: "Luz noturna: " + nlStatus + " · " + pLabel + " · " + idleStatus,
                icon: "󰛨",
                color: root.cYellow
            },
            {
                kind: "config_category",
                prefix: ":conexoes ",
                title: "Conexões e áudio",
                subtitle: "Wi-Fi, Bluetooth e mixer de áudio · Enter para opções",
                icon: "󰤨",
                color: root.cCyan
            },
            {
                kind: "config_category",
                prefix: ":captura ",
                title: "Captura e compartilhamento",
                subtitle: "Captura de tela, gravação e leitura de QR code",
                icon: "󰄡",
                color: root.cCyan
            },
            {
                kind: "config_category",
                prefix: ":sistema ",
                title: "Sistema e sessão",
                subtitle: "Informações e monitoramento do sistema, bloqueio e opções de energia",
                icon: "󰒓",
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
            color: root.cPink
        }
        const wpRandomItem = {
            kind: "wp_random",
            title: "Papel de parede aleatório",
            subtitle: "Escolher uma imagem e atualizar o tema",
            icon: "",
            color: root.cGreen
        }
        const cycleItem = {
            kind: "theme_cycle",
            title: "Usar próximo tema",
            subtitle: "Avançar na lista de temas (atual: " + (ThemeState.currentPalette?.name ?? ThemeState.currentTheme) + ")",
            icon: "󰔎",
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
                color: root.cYellow
            },
            {
                kind: "nightlight_set",
                val: true,
                title: "Ativar luz noturna agora",
                subtitle: "Ativar o filtro sem esperar pelo horário automático",
                icon: "󰛨",
                color: root.cYellow
            },
            {
                kind: "nightlight_set",
                val: false,
                title: "Desativar luz noturna",
                subtitle: "Desativar o filtro de temperatura",
                icon: "󰛩",
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
                color: IdleState.inhibited ? root.cGreen : root.cSecondary
            },
            {
                kind: "power_profile",
                profile: "performance",
                title: "Desempenho" + (curProfile === "performance" ? "  ✓" : ""),
                subtitle: "Prioriza o desempenho e permite frequências mais altas" + (curProfile === "performance" ? " (ativo)" : ""),
                icon: "󰓅",
                color: root.cGreen
            },
            {
                kind: "power_profile",
                profile: "balanced",
                title: "Equilibrado" + (curProfile === "balanced" ? "  ✓" : ""),
                subtitle: "Equilíbrio entre desempenho e economia de energia" + (curProfile === "balanced" ? " (ativo)" : ""),
                icon: "󰾆",
                color: root.cGreen
            },
            {
                kind: "power_profile",
                profile: "power-saver",
                title: "Economia de energia" + (curProfile === "power-saver" ? "  ✓" : ""),
                subtitle: "Reduz o desempenho para economizar bateria" + (curProfile === "power-saver" ? " (ativo)" : ""),
                icon: "󰌪",
                color: root.cGreen
            }
        ]
    }

    function connectionActions() {
        return [
            {
                kind: "app_exec",
                command: ["nm-connection-editor"],
                title: "Configurações de rede e Wi-Fi",
                subtitle: "Abrir o gerenciador de conexões de rede",
                icon: "󰤨",
                color: root.cCyan
            },
            {
                kind: "app_exec",
                command: ["blueberry"],
                title: "Dispositivos Bluetooth",
                subtitle: "Abrir painel de pareamento e conexões Bluetooth",
                icon: "󰂯",
                color: root.cCyan
            },
            {
                kind: "app_exec",
                command: ["pwvucontrol"],
                title: "Mixer de áudio",
                subtitle: "Ajustar entradas, saídas e canais de áudio",
                icon: "󰕾",
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
                color: root.cOrange
            },
            {
                kind: "restart_quickshell",
                title: "Reiniciar Quickshell",
                subtitle: "Recarregar a barra, os serviços e os popups",
                icon: "󰑓",
                color: root.cOrange
            },
            {
                kind: "app_exec",
                command: ["kitty", "htop"],
                title: "Monitor do sistema",
                subtitle: "Abrir o htop no Kitty",
                icon: "󰍹",
                color: root.cOrange
            }
        ]
    }

    function captureActions() {
        return [
            {
                kind: "system",
                title: "Captura de área",
                subtitle: "Selecionar uma região e copiar a imagem",
                icon: "󰹑",
                color: root.cCyan,
                command: [Quickshell.shellDir + "/scripts/screenshot.sh", "area"]
            },
            {
                kind: "system",
                title: "Gravar tela",
                subtitle: "Capturar a tela inteira sem áudio",
                icon: "󰕧",
                color: root.cCyan,
                command: ["python3", "-B", Quickshell.shellDir + "/scripts/screen-recording.py", "start", "screen"]
            },
            {
                kind: "system",
                title: "Gravar tela com áudio",
                subtitle: "Capturar a tela inteira com áudio do sistema e microfone",
                icon: "󰕾",
                color: root.cCyan,
                command: ["python3", "-B", Quickshell.shellDir + "/scripts/screen-recording.py", "start", "screen", "--audio"]
            },
            {
                kind: "system",
                title: "Ler QR code da tela",
                subtitle: "Selecionar uma região e copiar o código para a área de transferência",
                icon: "󰄡",
                color: root.cCyan,
                command: [Quickshell.shellDir + "/scripts/scan-qr.sh"]
            }
        ]
    }

    function sessionActions() {
        return [
            {
                kind: "system",
                title: "Bloquear sessão",
                subtitle: "Bloquear a tela imediatamente",
                icon: "󰌾",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "lock"]
            },
            {
                kind: "system",
                title: "Suspender",
                subtitle: "Suspender o computador (dormir)",
                icon: "󰤄",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "suspend"]
            },
            {
                kind: "system",
                title: "Encerrar sessão",
                subtitle: "Fechar aplicativos e encerrar sessão gráfica",
                icon: "󰗼",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "logout"]
            },
            {
                kind: "system",
                title: "Reiniciar computador",
                subtitle: "Reinicializar o sistema operacional",
                icon: "󰜉",
                color: root.cRed,
                command: [Quickshell.shellDir + "/scripts/session-action.sh", "reboot"]
            },
            {
                kind: "system",
                title: "Desligar computador",
                subtitle: "Fechar aplicativos e desligar o computador",
                icon: "󰐥",
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
