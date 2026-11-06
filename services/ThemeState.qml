pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "CommandResult.js" as CommandResult
import "ThemeRequest.js" as ThemeRequest

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property string currentTheme: "catppuccin-mocha"
    property string error: ""
    property var themeRequest: ThemeRequest.create()

    function applyCommandResult(text, includeCurrentTheme) {
        const response = CommandResult.decode(text)
        if (!response.ok) {
            root.error = response.error
            console.warn("Theme manager helper failed:", response.error)
            return
        }

        const result = response.data
        if (result.variants)
            root.dynamicVariants = result.variants
        if (result.theme && result.theme.id
                && result.theme.id.startsWith("chameleon") && result.theme.colors)
            root.dynamicChameleon = result.theme.colors
        if (includeCurrentTheme && result.current && root.palettes[result.current])
            root.currentTheme = result.current
        if (result.adapters)
            root.syncedAdapters = result.adapters
        root.error = ""
    }


    readonly property var themesList: [
        { id: "catppuccin-latte", name: "Catppuccin Latte", category: "light", accent: "#1e66f5" },
        { id: "catppuccin-frappe", name: "Catppuccin Frappé", category: "dark", accent: "#8caaee" },
        { id: "catppuccin-macchiato", name: "Catppuccin Macchiato", category: "dark", accent: "#8aadf4" },
        { id: "catppuccin-mocha", name: "Catppuccin Mocha", category: "dark", accent: "#89b4fa" },
        { id: "chameleon", name: "Chameleon", category: "dark", accent: root.palettes["chameleon"]?.accent ?? "#4ca8e0" },
        { id: "chameleon-light", name: "Chameleon Light", category: "light", accent: root.palettes["chameleon-light"]?.accent ?? "#4a6fa5" },
        { id: "chameleon-oled", name: "Chameleon OLED", category: "dark", accent: root.palettes["chameleon-oled"]?.accent ?? "#3ea9e7" },
        { id: "dracula", name: "Dracula", category: "dark", accent: "#bd93f9" },
        { id: "dracula-pro", name: "Dracula Pro", category: "dark", accent: "#9580ff" },
        { id: "dracula-pro-blade", name: "Dracula Pro Blade", category: "dark", accent: "#80ffea" },
        { id: "dracula-pro-van-helsing", name: "Dracula Pro Van Helsing", category: "dark", accent: "#9580ff" },
        { id: "everforest", name: "Everforest", category: "dark", accent: "#a7c080" },
        { id: "ghostty", name: "Ghostty", category: "dark", accent: "#82a2be" },
        { id: "gruvbox", name: "Gruvbox", category: "dark", accent: "#fe8019" },
        { id: "kanagawa", name: "Kanagawa Wave", category: "dark", accent: "#7e9cd8" },
        { id: "nord", name: "Nord", category: "dark", accent: "#88c0d0" },
        { id: "rose-pine", name: "Rosé Pine", category: "dark", accent: "#c4a7e7" },
        { id: "rose-pine-moon", name: "Rosé Pine Moon", category: "dark", accent: "#c4a7e7" },
        { id: "rose-pine-dawn", name: "Rosé Pine Dawn", category: "light", accent: "#286983" },
        { id: "solarized-dark", name: "Solarized", category: "dark", accent: "#268bd2" },
        { id: "tokyo-night", name: "Tokyo Night", category: "dark", accent: "#7aa2f7" }
    ]

    readonly property var palettes: ({
        "catppuccin-mocha": {
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            backgroundAlpha: 0.75,
            backgroundOpaque: "#1e1e2e",
            surface: "#313244",
            surfaceHover: "#45475a",
            foreground: "#cdd6f4",
            offWhite: "#bac2de",
            grey: "#585b70",
            red: "#f38ba8",
            green: "#a6e3a1",
            yellow: "#f9e2af",
            blue: "#89b4fa",
            pink: "#f5c2e7",
            cyan: "#94e2d5",
            orange: "#fab387",
            accent: "#89b4fa",
            selectionAccent: "#6c63bb",
            heroBackdropStart: "#181825",
            heroBackdropCenter: "#1e1e2e",
            heroBackdropEnd: "#11111b"
        },
        "catppuccin-frappe": {
            id: "catppuccin-frappe",
            name: "Catppuccin Frappé",
            backgroundAlpha: 0.75,
            backgroundOpaque: "#303446",
            surface: "#414559",
            surfaceHover: "#51576d",
            foreground: "#c6d0f5",
            offWhite: "#b5bfe2",
            grey: "#737994",
            red: "#e78284",
            green: "#a6d189",
            yellow: "#e5c890",
            blue: "#8caaee",
            pink: "#f4b8e4",
            cyan: "#81c8be",
            orange: "#ef9f76",
            accent: "#8caaee",
            selectionAccent: "#8caaee",
            heroBackdropStart: "#292c3c",
            heroBackdropCenter: "#303446",
            heroBackdropEnd: "#232634"
        },
        "catppuccin-macchiato": {
            id: "catppuccin-macchiato",
            name: "Catppuccin Macchiato",
            backgroundAlpha: 0.75,
            backgroundOpaque: "#24273a",
            surface: "#363a4f",
            surfaceHover: "#494d64",
            foreground: "#cad3f5",
            offWhite: "#b8c0e0",
            grey: "#6e738d",
            red: "#ed8796",
            green: "#a6da95",
            yellow: "#eed49f",
            blue: "#8aadf4",
            pink: "#f5bde6",
            cyan: "#8bd5ca",
            orange: "#f5a97f",
            accent: "#8aadf4",
            selectionAccent: "#8aadf4",
            heroBackdropStart: "#1e2030",
            heroBackdropCenter: "#24273a",
            heroBackdropEnd: "#181926"
        },
        "tokyo-night": {
            id: "tokyo-night",
            name: "Tokyo Night",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#1a1b26",
            surface: "#24283b",
            surfaceHover: "#2f3549",
            foreground: "#c0caf5",
            offWhite: "#a9b1d6",
            grey: "#565f89",
            red: "#f7768e",
            green: "#9ece6a",
            yellow: "#e0af68",
            blue: "#7aa2f7",
            pink: "#bb9af7",
            cyan: "#7dcfff",
            orange: "#ff9e64",
            accent: "#7aa2f7"
        },
        "nord": {
            id: "nord",
            name: "Nord",
            backgroundAlpha: 0.80,
            backgroundOpaque: "#2e3440",
            surface: "#3b4252",
            surfaceHover: "#434c5e",
            foreground: "#eceff4",
            offWhite: "#e5e9f0",
            grey: "#4c566a",
            red: "#bf616a",
            green: "#a3be8c",
            yellow: "#ebcb8b",
            blue: "#88c0d0",
            pink: "#b48ead",
            cyan: "#8fbcbb",
            orange: "#d08770",
            accent: "#88c0d0"
        },
        "gruvbox": {
            id: "gruvbox",
            name: "Gruvbox",
            backgroundAlpha: 0.82,
            backgroundOpaque: "#282828",
            surface: "#3c3836",
            surfaceHover: "#504945",
            foreground: "#ebdbb2",
            offWhite: "#d5c4a1",
            grey: "#665c54",
            red: "#fb4934",
            green: "#b8bb26",
            yellow: "#fabd2f",
            blue: "#83a598",
            pink: "#d3869b",
            cyan: "#8ec07c",
            orange: "#fe8019",
            accent: "#fe8019"
        },
        "dracula": {
            id: "dracula",
            name: "Dracula",
            backgroundAlpha: 0.80,
            backgroundOpaque: "#282a36",
            surface: "#343746",
            surfaceHover: "#44475a",
            foreground: "#f8f8f2",
            offWhite: "#e2e2dc",
            grey: "#6272a4",
            red: "#ff5555",
            green: "#50fa7b",
            yellow: "#f1fa8c",
            blue: "#bd93f9",
            pink: "#ff79c6",
            cyan: "#8be9fd",
            orange: "#ffb86c",
            accent: "#bd93f9"
        },
        "dracula-pro": {
            id: "dracula-pro",
            name: "Dracula Pro",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#22212c",
            surface: "#343346",
            surfaceHover: "#454158",
            foreground: "#f8f8f2",
            offWhite: "#e2e2ec",
            grey: "#7970a9",
            red: "#ff9580",
            green: "#8aff80",
            yellow: "#ffff80",
            blue: "#9580ff",
            pink: "#ff80bf",
            cyan: "#80ffea",
            orange: "#ffca80",
            accent: "#9580ff"
        },
        "dracula-pro-blade": {
            id: "dracula-pro-blade",
            name: "Dracula Pro Blade",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#212c2a",
            surface: "#313f3c",
            surfaceHover: "#415854",
            foreground: "#f8f8f2",
            offWhite: "#e2e2ec",
            grey: "#70a99f",
            red: "#ff9580",
            green: "#8aff80",
            yellow: "#ffff80",
            blue: "#9580ff",
            pink: "#ff80bf",
            cyan: "#80ffea",
            orange: "#ffca80",
            accent: "#80ffea"
        },
        "dracula-pro-van-helsing": {
            id: "dracula-pro-van-helsing",
            name: "Dracula Pro Van Helsing",
            backgroundAlpha: 0.85,
            backgroundOpaque: "#0b0d0f",
            surface: "#1b232a",
            surfaceHover: "#2c3742",
            foreground: "#f8f8f2",
            offWhite: "#e2e2ec",
            grey: "#708ca9",
            red: "#ff9580",
            green: "#8aff80",
            yellow: "#ffff80",
            blue: "#9580ff",
            pink: "#ff80bf",
            cyan: "#80ffea",
            orange: "#ffca80",
            accent: "#9580ff"
        },
        "everforest": {
            id: "everforest",
            name: "Everforest",
            backgroundAlpha: 0.80,
            backgroundOpaque: "#2d353b",
            surface: "#343f44",
            surfaceHover: "#3d484d",
            foreground: "#d3c6aa",
            offWhite: "#e6dfb8",
            grey: "#7a8478",
            red: "#e67e80",
            green: "#a7c080",
            yellow: "#dbbc7f",
            blue: "#7fbbb3",
            pink: "#d699b6",
            cyan: "#83c092",
            orange: "#e69875",
            accent: "#a7c080"
        },
        "kanagawa": {
            id: "kanagawa",
            name: "Kanagawa Wave",
            backgroundAlpha: 0.80,
            backgroundOpaque: "#1f1f28",
            surface: "#2a2a37",
            surfaceHover: "#363646",
            foreground: "#dcd7ba",
            offWhite: "#c8c093",
            grey: "#727169",
            red: "#c34043",
            green: "#76946a",
            yellow: "#c0a36e",
            blue: "#7e9cd8",
            pink: "#957fb8",
            cyan: "#7aa89f",
            orange: "#ffa066",
            accent: "#7e9cd8"
        },
        "solarized-dark": {
            id: "solarized-dark",
            name: "Solarized",
            backgroundAlpha: 0.80,
            backgroundOpaque: "#002b36",
            surface: "#073642",
            surfaceHover: "#0f4a59",
            foreground: "#b8c4c5",
            offWhite: "#b8c4c5",
            grey: "#586e75",
            red: "#dc322f",
            green: "#859900",
            yellow: "#b58900",
            blue: "#268bd2",
            pink: "#d33682",
            cyan: "#2aa198",
            orange: "#cb4b16",
            accent: "#268bd2"
        },
        "rose-pine": {
            id: "rose-pine",
            name: "Rosé Pine",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#191724",
            surface: "#1f1d2e",
            surfaceHover: "#26233a",
            foreground: "#e0def4",
            offWhite: "#908caa",
            grey: "#6e6a86",
            red: "#eb6f92",
            green: "#9ccfd8",
            yellow: "#f6c177",
            blue: "#31748f",
            pink: "#ebbcba",
            cyan: "#c4a7e7",
            orange: "#ea9a97",
            accent: "#c4a7e7"
        },
        "rose-pine-moon": {
            id: "rose-pine-moon",
            name: "Rosé Pine Moon",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#232136",
            surface: "#2a273f",
            surfaceHover: "#393552",
            foreground: "#e0def4",
            offWhite: "#908caa",
            grey: "#6e6a86",
            red: "#eb6f92",
            green: "#9ccfd8",
            yellow: "#f6c177",
            blue: "#3e8fb0",
            pink: "#ea9a97",
            cyan: "#c4a7e7",
            orange: "#ea9a97",
            accent: "#c4a7e7",
            selectionAccent: "#c4a7e7",
            heroBackdropStart: "#1b1928",
            heroBackdropCenter: "#232136",
            heroBackdropEnd: "#1b1928"
        },
        "rose-pine-dawn": {
            id: "rose-pine-dawn",
            name: "Rosé Pine Dawn",
            category: "light",
            backgroundAlpha: 0.94,
            backgroundOpaque: "#faf4ed",
            surface: "#fffaf3",
            surfaceHover: "#f2e9e1",
            foreground: "#575279",
            offWhite: "#797593",
            grey: "#9893a5",
            red: "#b4637a",
            green: "#56949f",
            yellow: "#ea9d34",
            blue: "#286983",
            pink: "#d7827e",
            cyan: "#907aa9",
            orange: "#d7827e",
            accent: "#286983",
            selectionAccent: "#286983",
            heroBackdropStart: "#f4ede8",
            heroBackdropCenter: "#faf4ed",
            heroBackdropEnd: "#fffaf3"
        },
        "catppuccin-latte": {
            id: "catppuccin-latte",
            name: "Catppuccin Latte",
            category: "light",
            backgroundAlpha: 0.94,
            backgroundOpaque: "#eff1f5",
            surface: "#e6e9ef",
            surfaceHover: "#dce0e8",
            foreground: "#4c4f69",
            offWhite: "#5c5f77",
            grey: "#8c8fa1",
            red: "#d20f39",
            green: "#40a02b",
            yellow: "#df8e1d",
            blue: "#1e66f5",
            pink: "#ea76cb",
            cyan: "#179299",
            orange: "#fe640b",
            accent: "#1e66f5",
            surfaceVariant: "#dce0e8"
        },
        "ghostty": {
            id: "ghostty",
            name: "Ghostty",
            backgroundAlpha: 0.78,
            backgroundOpaque: "#282c34",
            surface: "#353b45",
            surfaceHover: "#404754",
            foreground: "#eaeaea",
            offWhite: "#c4c8c6",
            grey: "#7c828d",
            red: "#d54e53",
            green: "#b9ca4b",
            yellow: "#e7c547",
            blue: "#82a2be",
            pink: "#c397d8",
            cyan: "#70c0b1",
            orange: "#e78c45",
            accent: "#82a2be",
            surfaceVariant: "#404754"
        },
        "chameleon": {
            id: "chameleon",
            name: "Chameleon",
            category: "dark",
            backgroundAlpha: dynamicVariants["chameleon"]?.colors?.backgroundAlpha ?? dynamicChameleon?.backgroundAlpha ?? 0.78,
            backgroundOpaque: dynamicVariants["chameleon"]?.colors?.backgroundOpaque ?? dynamicChameleon?.backgroundOpaque ?? "#06131b",
            surface: dynamicVariants["chameleon"]?.colors?.surface ?? dynamicChameleon?.surface ?? "#12212b",
            surfaceElevated: dynamicVariants["chameleon"]?.colors?.surfaceElevated ?? dynamicChameleon?.surfaceElevated ?? "#1c2e38",
            surfaceHover: dynamicVariants["chameleon"]?.colors?.surfaceHover ?? dynamicChameleon?.surfaceHover ?? "#283b46",
            surfaceSelected: dynamicVariants["chameleon"]?.colors?.surfaceSelected ?? dynamicChameleon?.surfaceSelected ?? "#354b58",
            surfaceVariant: dynamicVariants["chameleon"]?.colors?.surfaceVariant ?? dynamicChameleon?.surfaceVariant ?? "#1c2e38",
            border: dynamicVariants["chameleon"]?.colors?.border ?? dynamicChameleon?.border ?? "#2e404b",
            borderSubtle: dynamicVariants["chameleon"]?.colors?.borderSubtle ?? dynamicChameleon?.borderSubtle ?? "#223039",
            foreground: dynamicVariants["chameleon"]?.colors?.foreground ?? dynamicChameleon?.foreground ?? "#ecf3f8",
            offWhite: dynamicVariants["chameleon"]?.colors?.offWhite ?? dynamicChameleon?.offWhite ?? "#cfd9e0",
            onSurfaceVariant: dynamicVariants["chameleon"]?.colors?.onSurfaceVariant ?? dynamicChameleon?.onSurfaceVariant ?? "#cfd9e0",
            grey: dynamicVariants["chameleon"]?.colors?.grey ?? dynamicChameleon?.grey ?? "#8d9ba3",
            textMuted: dynamicVariants["chameleon"]?.colors?.textMuted ?? dynamicChameleon?.textMuted ?? "#707c85",
            textDisabled: dynamicVariants["chameleon"]?.colors?.textDisabled ?? dynamicChameleon?.textDisabled ?? "#4e575d",
            red: dynamicVariants["chameleon"]?.colors?.red ?? dynamicChameleon?.red ?? "#e86884",
            green: dynamicVariants["chameleon"]?.colors?.green ?? dynamicChameleon?.green ?? "#56c888",
            yellow: dynamicVariants["chameleon"]?.colors?.yellow ?? dynamicChameleon?.yellow ?? "#d3d165",
            blue: dynamicVariants["chameleon"]?.colors?.blue ?? dynamicChameleon?.blue ?? "#43a6ee",
            pink: dynamicVariants["chameleon"]?.colors?.pink ?? dynamicChameleon?.pink ?? "#d390e6",
            cyan: dynamicVariants["chameleon"]?.colors?.cyan ?? dynamicChameleon?.cyan ?? "#4fccd8",
            orange: dynamicVariants["chameleon"]?.colors?.orange ?? dynamicChameleon?.orange ?? "#f98a72",
            accent: dynamicVariants["chameleon"]?.colors?.accent ?? dynamicChameleon?.accent ?? "#3aaae4",
            accentMuted: dynamicVariants["chameleon"]?.colors?.accentMuted ?? dynamicChameleon?.accentMuted ?? "#2a5269"
        },
        "chameleon-oled": {
            id: "chameleon-oled",
            name: "Chameleon OLED",
            category: "dark",
            backgroundAlpha: dynamicVariants["chameleon-oled"]?.colors?.backgroundAlpha ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.backgroundAlpha : null) ?? 0.96,
            backgroundOpaque: dynamicVariants["chameleon-oled"]?.colors?.backgroundOpaque ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.backgroundOpaque : null) ?? "#000000",
            surface: dynamicVariants["chameleon-oled"]?.colors?.surface ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.surface : null) ?? "#0c1015",
            surfaceElevated: dynamicVariants["chameleon-oled"]?.colors?.surfaceElevated ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.surfaceElevated : null) ?? "#141a20",
            surfaceHover: dynamicVariants["chameleon-oled"]?.colors?.surfaceHover ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.surfaceHover : null) ?? "#1e252c",
            surfaceSelected: dynamicVariants["chameleon-oled"]?.colors?.surfaceSelected ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.surfaceSelected : null) ?? "#28323b",
            surfaceVariant: dynamicVariants["chameleon-oled"]?.colors?.surfaceVariant ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.surfaceVariant : null) ?? "#141a20",
            border: dynamicVariants["chameleon-oled"]?.colors?.border ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.border : null) ?? "#26303a",
            borderSubtle: dynamicVariants["chameleon-oled"]?.colors?.borderSubtle ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.borderSubtle : null) ?? "#182028",
            foreground: dynamicVariants["chameleon-oled"]?.colors?.foreground ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.foreground : null) ?? "#ffffff",
            offWhite: dynamicVariants["chameleon-oled"]?.colors?.offWhite ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.offWhite : null) ?? "#dce2e8",
            onSurfaceVariant: dynamicVariants["chameleon-oled"]?.colors?.onSurfaceVariant ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.onSurfaceVariant : null) ?? "#dce2e8",
            grey: dynamicVariants["chameleon-oled"]?.colors?.grey ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.grey : null) ?? "#8d9aa3",
            textMuted: dynamicVariants["chameleon-oled"]?.colors?.textMuted ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.textMuted : null) ?? "#707d86",
            textDisabled: dynamicVariants["chameleon-oled"]?.colors?.textDisabled ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.textDisabled : null) ?? "#4a555e",
            red: dynamicVariants["chameleon-oled"]?.colors?.red ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.red : null) ?? "#f25d81",
            green: dynamicVariants["chameleon-oled"]?.colors?.green ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.green : null) ?? "#3dcb81",
            yellow: dynamicVariants["chameleon-oled"]?.colors?.yellow ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.yellow : null) ?? "#d5d14f",
            blue: dynamicVariants["chameleon-oled"]?.colors?.blue ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.blue : null) ?? "#26a7fa",
            pink: dynamicVariants["chameleon-oled"]?.colors?.pink ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.pink : null) ?? "#d98aee",
            cyan: dynamicVariants["chameleon-oled"]?.colors?.cyan ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.cyan : null) ?? "#29cedd",
            orange: dynamicVariants["chameleon-oled"]?.colors?.orange ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.orange : null) ?? "#ff8368",
            accent: dynamicVariants["chameleon-oled"]?.colors?.accent ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.accent : null) ?? "#27b8fc",
            accentMuted: dynamicVariants["chameleon-oled"]?.colors?.accentMuted ?? (root.currentTheme === "chameleon-oled" ? dynamicChameleon?.accentMuted : null) ?? "#1a3b50"
        },
        "chameleon-light": {
            id: "chameleon-light",
            name: "Chameleon Light",
            category: "light",
            backgroundAlpha: dynamicVariants["chameleon-light"]?.colors?.backgroundAlpha ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.backgroundAlpha : null) ?? 0.94,
            backgroundOpaque: dynamicVariants["chameleon-light"]?.colors?.backgroundOpaque ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.backgroundOpaque : null) ?? "#eef0f6",
            surface: dynamicVariants["chameleon-light"]?.colors?.surface ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.surface : null) ?? "#e6e9f1",
            surfaceElevated: dynamicVariants["chameleon-light"]?.colors?.surfaceElevated ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.surfaceElevated : null) ?? "#dde1ea",
            surfaceHover: dynamicVariants["chameleon-light"]?.colors?.surfaceHover ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.surfaceHover : null) ?? "#d3d8e3",
            surfaceSelected: dynamicVariants["chameleon-light"]?.colors?.surfaceSelected ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.surfaceSelected : null) ?? "#c3cbda",
            surfaceVariant: dynamicVariants["chameleon-light"]?.colors?.surfaceVariant ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.surfaceVariant : null) ?? "#dde1ea",
            border: dynamicVariants["chameleon-light"]?.colors?.border ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.border : null) ?? "#b9c1d1",
            borderSubtle: dynamicVariants["chameleon-light"]?.colors?.borderSubtle ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.borderSubtle : null) ?? "#cfd5e2",
            foreground: dynamicVariants["chameleon-light"]?.colors?.foreground ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.foreground : null) ?? "#232838",
            offWhite: dynamicVariants["chameleon-light"]?.colors?.offWhite ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.offWhite : null) ?? "#39415a",
            onSurfaceVariant: dynamicVariants["chameleon-light"]?.colors?.onSurfaceVariant ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.onSurfaceVariant : null) ?? "#39415a",
            grey: dynamicVariants["chameleon-light"]?.colors?.grey ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.grey : null) ?? "#6b7490",
            textMuted: dynamicVariants["chameleon-light"]?.colors?.textMuted ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.textMuted : null) ?? "#6b7490",
            textDisabled: dynamicVariants["chameleon-light"]?.colors?.textDisabled ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.textDisabled : null) ?? "#9aa2b8",
            red: dynamicVariants["chameleon-light"]?.colors?.red ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.red : null) ?? "#c94f5e",
            green: dynamicVariants["chameleon-light"]?.colors?.green ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.green : null) ?? "#3d8a52",
            yellow: dynamicVariants["chameleon-light"]?.colors?.yellow ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.yellow : null) ?? "#9a7414",
            blue: dynamicVariants["chameleon-light"]?.colors?.blue ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.blue : null) ?? "#2f6fd0",
            pink: dynamicVariants["chameleon-light"]?.colors?.pink ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.pink : null) ?? "#b050a8",
            cyan: dynamicVariants["chameleon-light"]?.colors?.cyan ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.cyan : null) ?? "#1f8a94",
            orange: dynamicVariants["chameleon-light"]?.colors?.orange ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.orange : null) ?? "#c25a1e",
            accent: dynamicVariants["chameleon-light"]?.colors?.accent ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.accent : null) ?? "#4a6fa5",
            accentMuted: dynamicVariants["chameleon-light"]?.colors?.accentMuted ?? (root.currentTheme === "chameleon-light" ? dynamicChameleon?.accentMuted : null) ?? "#b9c9e4"
        }
    })

    property var dynamicVariants: ({})
    property var dynamicChameleon: null
    property var syncedAdapters: ({ "quickshell": true, "kitty": false, "ghostty": false, "hyprland": false, "hyprlock": false, "gtk": false, "btop": false, "qt": false, "labwc": false, "mango": false })

    readonly property var currentPalette: palettes[currentTheme] ?? palettes["catppuccin-mocha"]

    function refresh() {
        if (!initProc.running && !setProc.running && !updateProc.running
                && !root.themeRequest.pending)
            initProc.running = true
    }

    function setTheme(name) {
        const id = String(name ?? "").trim().toLowerCase()
        if (palettes[id]) {
            root.currentTheme = id
            ThemeRequest.request(root.themeRequest, id)
            setDebounce.restart()
        }
    }

    Timer {
        id: setDebounce
        interval: 150
        repeat: false
        onTriggered: {
            if (setProc.running || updateProc.running || initProc.running) {
                setDebounce.restart()
                return
            }
            const id = ThemeRequest.take(root.themeRequest)
            if (!id)
                return
            setProc.revision = root.themeRequest.revision
            setProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "set", id]
            setProc.running = true
        }
    }

    function nextTheme() {
        const keys = themesList.map(t => t.id)
        const idx = keys.indexOf(root.currentTheme)
        const nextId = keys[(idx + 1) % keys.length]
        root.setTheme(nextId)
    }

    Timer {
        id: refreshDebounce
        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    // Wallpaper trocado com chameleon ativo: sync completo de adapters
    // (update-wallpaper é no-op quando o cache já corresponde).
    Timer {
        id: updateDebounce
        interval: 600
        repeat: false
        onTriggered: {
            if (updateProc.running || setProc.running || initProc.running || root.themeRequest.pending) {
                updateDebounce.restart()
            } else {
                updateProc.revision = root.themeRequest.revision
                updateProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "update-wallpaper"]
                updateProc.running = true
            }
        }
    }

    FileView {
        id: wallpaperWatcher
        path: ShellPaths.currentWallpaper
        watchChanges: true
        printErrors: false

        onFileChanged: {
            this.reload()
            if (root.currentTheme.startsWith("chameleon")) {
                updateDebounce.restart()
            }
        }
    }

    FileView {
        id: paletteWatcher
        path: (Quickshell.env("XDG_STATE_HOME") && Quickshell.env("XDG_STATE_HOME").length > 0)
              ? (Quickshell.env("XDG_STATE_HOME") + "/quickshell/chameleon-palette.json")
              : (Quickshell.env("HOME") + "/.local/state/quickshell/chameleon-palette.json")
        watchChanges: true
        printErrors: false

        onFileChanged: {
            this.reload()
            if (root.currentTheme.startsWith("chameleon")) {
                refreshDebounce.restart()
            }
        }
    }

    Process {
        id: setProc
        property int revision: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (ThemeRequest.isCurrent(root.themeRequest, setProc.revision))
                    root.applyCommandResult(this.text, false)
            }
        }
    }

    Process {
        id: updateProc
        property int revision: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (ThemeRequest.isCurrent(root.themeRequest, updateProc.revision))
                    root.applyCommandResult(this.text, false)
            }
        }
    }

    Process {
        id: initProc
        property int revision: 0
        onRunningChanged: {
            if (running)
                revision = root.themeRequest.revision
        }
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (ThemeRequest.isCurrent(root.themeRequest, initProc.revision)) {
                    root.applyCommandResult(this.text, true)
                    hyprlockInitProc.running = true
                }
            }
        }
    }

    Process {
        id: hyprlockInitProc
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/theme-manager.py", "sync-hyprlock"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    if (!result.ok)
                        console.warn("ThemeState: Hyprlock palette bootstrap failed:", result.error)
                } catch (error) {
                    console.warn("ThemeState: invalid Hyprlock palette bootstrap response:", error)
                }
            }
        }
    }
}
