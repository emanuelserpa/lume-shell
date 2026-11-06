import QtQuick
import Quickshell
import qs.services

QtObject {
    id: root

    readonly property string currentTheme: ThemeState.currentTheme
    readonly property var palette: ThemeState.currentPalette
    readonly property var materialPalette: ThemeState.dynamicVariants[currentTheme]?.colors ?? ({})

    readonly property bool isLight: (palette.category ?? "dark") === "light"

    readonly property bool hyprlandSession: MotionState.hyprlandSession
    // Visual transitions stay in Quickshell across compositors.
    readonly property bool qmlAnimationsEnabled: MotionState.qmlAnimationsEnabled
    readonly property real requestedGlassAlpha: GlassState.alpha

    // labwc has no blur: translucent surfaces show the raw background.
    // Floor the base alpha there so the shell stays readable. Hyprland
    // caps surface alpha so blur remains visible across all shell popups.
    readonly property bool labwcSession: {
        if ((Quickshell.env("LABWC_PID") ?? "") !== "")
            return true
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase()
        return desktop.split(":").includes("labwc")
    }
    readonly property bool mangoSession: {
        if ((Quickshell.env("MANGO_INSTANCE_SIGNATURE") ?? "") !== "")
            return true
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase()
        return desktop.split(":").some(name => name === "mango" || name === "mangowc")
    }
    readonly property real backgroundAlpha: {
        const base = root.requestedGlassAlpha
        // Keep all shell surfaces translucent enough for compositor blur to
        // read as frosted glass, while leaving a solid floor on no-blur labwc.
        return root.labwcSession ? Math.min(1.0, Math.max(base, 0.92)) : Math.min(base, 0.68)
    }
    readonly property color backgroundOpaque: palette.backgroundOpaque ?? (isLight ? "#eff1f5" : "#1e1e2e")
    readonly property color background: Qt.rgba(backgroundOpaque.r, backgroundOpaque.g, backgroundOpaque.b, backgroundAlpha)
    // Mango does not blur xdg-popup surfaces yet. Keep only PopupWindow cards
    // nearly opaque there; layer surfaces retain the normal translucent token.
    readonly property color popupBackground: Qt.rgba(
        backgroundOpaque.r,
        backgroundOpaque.g,
        backgroundOpaque.b,
        mangoSession ? Math.max(backgroundAlpha, 0.92) : backgroundAlpha
    )
    readonly property color notificationBackground: background
    readonly property color surface: palette.surface ?? (isLight ? "#e6e9ef" : "#313244")
    readonly property color surfaceHover: palette.surfaceHover ?? (isLight ? "#dce0e8" : "#45475a")
    readonly property color foreground: palette.foreground ?? (isLight ? "#4c4f69" : "#cdd6f4")
    readonly property color offWhite: palette.offWhite ?? (isLight ? "#5c5f77" : "#bac2de")
    readonly property color grey: palette.grey ?? (isLight ? "#8c8fa1" : "#585b70")
    readonly property color red: palette.red ?? (isLight ? "#d20f39" : "#f38ba8")
    readonly property color green: palette.green ?? (isLight ? "#40a02b" : "#a6e3a1")
    readonly property color yellow: palette.yellow ?? (isLight ? "#df8e1d" : "#f9e2af")
    readonly property color blue: palette.blue ?? (isLight ? "#1e66f5" : "#89b4fa")
    readonly property color pink: palette.pink ?? (isLight ? "#ea76cb" : "#f5c2e7")
    readonly property color cyan: palette.cyan ?? (isLight ? "#179299" : "#94e2d5")
    readonly property color orange: palette.orange ?? (isLight ? "#fe640b" : "#fab387")
    readonly property color accent: palette.accent ?? blue
    readonly property color surfaceVariant: palette.surfaceVariant ?? surfaceHover
    readonly property color surfaceElevated: palette.surfaceElevated ?? (isLight ? "#ffffff" : surfaceHover)
    readonly property color surfaceSelected: palette.surfaceSelected ?? accent
    readonly property color selectionAccent: palette.selectionAccent ?? surfaceSelected
    readonly property color pureWhite: "#ffffff"
    readonly property color pureBlack: "#000000"
    readonly property color heroBackdropStart: palette.heroBackdropStart ?? Qt.darker(backgroundOpaque, 1.25)
    readonly property color heroBackdropCenter: palette.heroBackdropCenter ?? backgroundOpaque
    readonly property color heroBackdropEnd: palette.heroBackdropEnd ?? Qt.darker(backgroundOpaque, 1.70)
    readonly property color border: palette.border ?? borderRegular
    readonly property color accentMuted: palette.accentMuted ?? Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color textMuted: palette.textMuted ?? surfaceVariantForeground
    readonly property color textDisabled: palette.textDisabled ?? Qt.rgba(grey.r, grey.g, grey.b, 0.50)

    // Material Design 3 State Layers (standard interaction opacities)
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.12
    readonly property real statePress: 0.12
    readonly property real stateDragged: 0.16

    // Material Design 3 / Material You Tokens
    readonly property color primary: materialPalette["primary"] ?? palette.primary ?? accent
    readonly property color primaryForeground: materialPalette["onPrimary"] ?? (isLight ? "#ffffff" : backgroundOpaque)
    readonly property color primaryContainer: materialPalette["primaryContainer"] ?? palette.primaryContainer ?? accentMuted
    readonly property color primaryContainerForeground: materialPalette["onPrimaryContainer"] ?? foreground
    readonly property color secondary: materialPalette["secondary"] ?? palette.secondary ?? cyan
    readonly property color secondaryContainer: materialPalette["secondaryContainer"] ?? palette.secondaryContainer ?? surfaceContainerHigh
    readonly property color secondaryContainerForeground: materialPalette["onSecondaryContainer"] ?? foreground
    readonly property color tertiary: materialPalette["tertiary"] ?? palette.tertiary ?? pink
    readonly property color error: materialPalette["error"] ?? palette.error ?? red
    readonly property color errorForeground: materialPalette["onError"] ?? (isLight ? "#ffffff" : backgroundOpaque)
    readonly property color errorContainer: materialPalette["errorContainer"] ?? palette.errorContainer ?? surfaceContainerHigh
    readonly property color errorContainerForeground: materialPalette["onErrorContainer"] ?? foreground
    readonly property color surfaceContainerLowest: materialPalette["surfaceContainerLowest"] ?? palette.surfaceContainerLowest ?? (isLight ? "#ffffff" : Qt.darker(backgroundOpaque, 1.35))
    readonly property color surfaceContainerLow: materialPalette["surfaceContainerLow"] ?? palette.surfaceContainerLow ?? (isLight ? "#f6f6f8" : Qt.darker(backgroundOpaque, 1.15))
    readonly property color surfaceContainer: materialPalette["surfaceContainer"] ?? palette.surfaceContainer ?? surface
    readonly property color surfaceContainerHigh: materialPalette["surfaceContainerHigh"] ?? palette.surfaceContainerHigh ?? surfaceHover
    readonly property color surfaceContainerHighest: materialPalette["surfaceContainerHighest"] ?? palette.surfaceContainerHighest ?? (palette.surfaceVariant ?? surfaceHover)
    readonly property color surfaceForeground: materialPalette["onSurface"] ?? foreground
    readonly property color surfaceVariantForeground: materialPalette["onSurfaceVariant"] ?? offWhite
    readonly property color outline: materialPalette["outline"] ?? palette.outline ?? border
    readonly property color outlineVariant: materialPalette["outlineVariant"] ?? palette.outlineVariant ?? (isLight ? Qt.rgba(grey.r, grey.g, grey.b, 0.18) : Qt.rgba(grey.r, grey.g, grey.b, 0.22))


    // Design Tokens - Radiuses
    readonly property int radiusXs: 4
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 20
    readonly property int radiusPopup: 26
    readonly property int radiusButton: 14

    // Shared motion scale: press, state feedback, layout, then transient fades.
    readonly property int motionPress: 90
    readonly property int motionFast: 140
    readonly property int motionStandard: 190
    readonly property int motionLayout: 200
    readonly property int motionPopup: 200
    readonly property int motionPopupExit: 150
    readonly property real motionPressScale: 0.96
    readonly property real motionPopupScale: 0.97
    readonly property int motionPopupOffset: 8
    readonly property int motionTransientFadeDuration: 210
    readonly property int motionTransientFadeEasing: Easing.InOutSine
    readonly property int motionEasing: Easing.OutCubic

    function withAlpha(baseColor, opacity) {
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, opacity)
    }

    function glassOpacity(baseOpacity) {
        return Math.max(0.12, Math.min(0.78, baseOpacity + root.requestedGlassAlpha - 0.68))
    }

    function stateLayer(baseColor, state) {
        const opacity = state === "hover" ? stateHover
                      : state === "focus" ? stateFocus
                      : state === "pressed" ? statePress
                      : state === "dragged" ? stateDragged
                      : 0
        return opacity > 0 ? withAlpha(baseColor, opacity) : "transparent"
    }

    // Design Tokens - Popup Glass Surfaces
    // Use the same four opacity levels for popup contents; keep text opaque.
    readonly property color glassPanelSurface: withAlpha(surfaceContainerLow, glassOpacity(0.55))
    readonly property color glassCardSurface: withAlpha(surfaceContainerHigh, glassOpacity(0.32))
    readonly property color glassHoverSurface: withAlpha(surfaceContainerHighest, glassOpacity(0.45))
    readonly property color glassActiveSurface: withAlpha(primaryContainer, glassOpacity(0.36))

    // Adaptive Soft UI surfaces use palette roles for tonal depth while the
    // outer popup keeps its compositor-aware glass background.
    readonly property color adaptiveCardSurface: surfaceContainerLow
    readonly property color adaptiveCardHoverSurface: surfaceContainer
    readonly property color adaptiveCardActiveSurface: primaryContainer
    readonly property color adaptiveCardBorder: outlineVariant
    // Keeps album artwork atmospheric while preserving text contrast.
    readonly property color mediaArtworkOverlay: withAlpha(backgroundOpaque, 0.78)

    // Design Tokens - Sliders & Progress
    readonly property color sliderTrack: palette.sliderTrack ?? (isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.22)
        : Qt.rgba(grey.r, grey.g, grey.b, 0.32))

    // Design Tokens - Borders & Glass Rims
    readonly property color borderSubtle: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.22)
        : Qt.rgba(surfaceHover.r, surfaceHover.g, surfaceHover.b, 0.30)

    readonly property color borderRegular: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.32)
        : Qt.rgba(surfaceHover.r, surfaceHover.g, surfaceHover.b, 0.45)

    readonly property color borderPopup: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.40)
        : Qt.rgba(surfaceHover.r, surfaceHover.g, surfaceHover.b, 0.72)

    readonly property color glassBorder: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.22)
        : Qt.rgba(1.0, 1.0, 1.0, 0.12)

    readonly property color glassBorderSubtle: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.14)
        : Qt.rgba(1.0, 1.0, 1.0, 0.08)

    // Design Tokens - Pills & Chips (harmonized with Media pill)
    readonly property int pillHeight: 22
    readonly property int pillRadius: 6

    // Compact top-bar geometry. Keep the reserved height stable for tiling.
    readonly property int barHeight: 37
    readonly property int barPanelInset: 3
    readonly property int barContentHeight: 29
    readonly property int barIslandHeight: barHeight - (barPanelInset * 2)
    readonly property int barIslandRadius: barIslandHeight / 2
    readonly property int barIslandPadding: 8
    readonly property int barIslandSpacing: 6
    readonly property int barIslandShadowOffset: 1
    readonly property int barWorkspaceMinWidth: 24
    readonly property int barWorkspaceHorizontalPadding: 8
    readonly property int barTrayItemWidth: 18
    readonly property int barTrayIconSize: 14
    readonly property int barIconSize: 15
    readonly property int barIndicatorSize: 22

    readonly property color pillBackground: isLight
        ? Qt.rgba(1.0, 1.0, 1.0, 0.85)
        : Qt.rgba(surface.r, surface.g, surface.b, 0.50)

    readonly property color barIslandSurface: background
    readonly property color barIslandBorder: glassBorder
    readonly property color barIslandShadow:
        withAlpha(Qt.darker(backgroundOpaque, 1.35), isLight ? 0.32 : 0.24)

    readonly property color pillBackgroundHover: isLight
        ? Qt.rgba(1.0, 1.0, 1.0, 0.98)
        : Qt.rgba(surfaceHover.r, surfaceHover.g, surfaceHover.b, 0.65)

    readonly property color pillBorder: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.28)
        : Qt.rgba(surfaceHover.r, surfaceHover.g, surfaceHover.b, 0.35)

    readonly property color pillBorderHover: isLight
        ? Qt.rgba(grey.r, grey.g, grey.b, 0.50)
        : Qt.rgba(grey.r, grey.g, grey.b, 0.55)

    // Mixed text + icons: keep proportional spacing with proportional spacing.
    readonly property string fontFamily: "Noto Sans"
    readonly property string nerdFontFamily: "Noto Sans Nerd Font"
    // Pure icon labels can use the symbol font directly.
    readonly property string iconFontFamily: "Symbols Nerd Font"
    readonly property string monoFontFamily: "JetBrainsMono Nerd Font"

    // Shared popup spacing scale. Values preserve the current compact layout.
    readonly property var spacingTokens: ({
        "micro": 1,
        "tiny": 2,
        "tight": 3,
        "xs": 4,
        "xsPlus": 5,
        "sm": 6,
        "smPlus": 7,
        "md": 8,
        "mdPlus": 9,
        "lg": 10,
        "lgPlus": 11,
        "xl": 12,
        "xxlPlus": 13,
        "xxl": 14,
        "xxxl": 18,
        "hero": 20
    })
    readonly property var popupInsets: ({
        "micro": 3,
        "small": 6,
        "smallPlus": 7,
        "compact": 8,
        "compactPlus": 9,
        "standard": 10,
        "large": 12,
        "outer": 14,
        "panel": 16
    })
    readonly property var popupWidths: ({
        "small": 260,
        "medium": 340,
        "large": 380
    })
    readonly property var sliderTokens: ({
        "trackHeight": 11,
        "thumbSize": 18
    })
    readonly property int softControlHeight: 52
    readonly property var iconTokens: ({
        "xs": 9,
        "sm": 10,
        "smPlus": 11,
        "md": 12,
        "mdPlus": 13,
        "lg": 14,
        "lgPlus": 15,
        "xl": 16,
        "xxlPlus": 17,
        "xxl": 18,
        "mediaControl": 22,
        "mediaPrimaryControl": 26,
        "hero": 20
    })
    readonly property var typeTokens: ({
        "caption": 8,
        "meta": 9,
        "body": 10,
        "subtitle": 11,
        "bodyEmphasis": 12,
        "title": 13,
        "titleMedium": 14,
        "titleLarge": 15,
        "heading": 16,
        "display": 18,
        "metricLarge": 17,
        "metric": 20
    })

    // Spotlight type scale: query, title, body, label and compact keycap.
    readonly property int spotlightQueryFontSize: 18
    readonly property int spotlightTitleFontSize: 13
    readonly property int spotlightBodyFontSize: 11
    readonly property int spotlightLabelFontSize: 10
    readonly property int spotlightKeycapFontSize: 9
    readonly property int spotlightHintFontSize: 15

    // Spotlight icon hierarchy shared by search modes, results, and details.
    // Emoji keeps a larger, purpose-specific size because it is the result.
    readonly property var spotlightIconTokens: ({
        "mode": 20,
        "result": 24,
        "detail": 28,
        "action": 14,
        "emoji": 28
    })

    // Shared scale for the weather, calendar, and controls dashboard cards.
    readonly property int dashboardHeadingFontSize: 14
    readonly property int dashboardTitleFontSize: 12
    readonly property int dashboardBodyFontSize: 11
    readonly property int dashboardLabelFontSize: 10
    readonly property int dashboardMetaFontSize: 10
    readonly property int dashboardHeroFontSize: 30
    readonly property int dashboardMetricFontSize: 16
    readonly property int dashboardCompactMetricFontSize: 13

    readonly property int fontSize: 13
}
