pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property var player: null
    property var players: []
    property bool hoverPreview: false
    signal playerSelected(var player)
    readonly property bool containsPointer: cardHover.hovered

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 330
    implicitHeight: contentColumn.implicitHeight + 28

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: !hoverPreview

    property bool showPlayerList: false

    readonly property var otherPlayers: (players ?? []).filter(function(p) { return p !== player })


    onVisibleChanged: {
        if (visible) {
            showPlayerList = false
            if (!hoverPreview) card.forceActiveFocus()
        }
    }

    PopupOutsideClick {
        popupWindow: root
        focusGrabEnabled: root.hoverPreview
        onDismissed: root.visible = false
    }

    onPlayerChanged: {
        if (root.visible && root.theme.qmlAnimationsEnabled) playerSwapAnim.restart()
    }

    onHoverPreviewChanged: {
        if (visible && !hoverPreview) card.forceActiveFocus()
    }

    readonly property string title:
        String(player?.trackTitle ?? "").trim().length > 0
        ? String(player.trackTitle).trim()
        : "Sem título"

    readonly property string artist: {
        const direct = String(player?.trackArtist ?? "").trim()
        if (direct.length > 0) return direct

        const albumArtist = String(player?.trackAlbumArtist ?? "").trim()
        if (albumArtist.length > 0) return albumArtist

        try {
            const raw = player?.metadata ? player.metadata["xesam:artist"] : null

            if (raw !== null && raw !== undefined) {
                if (Array.isArray(raw))
                    return raw.map(x => String(x).trim())
                              .filter(x => x.length > 0)
                              .join(", ")

                const value = String(raw).trim()
                if (value.length > 0)
                    return value
            }
        } catch (e) {
        }

        return "Artista desconhecido"
    }

    readonly property string album: String(player?.trackAlbum ?? "").trim()
    readonly property string artUrl: String(player?.trackArtUrl ?? "").trim()

    readonly property real lengthSec: Number(player?.length ?? 0)
    readonly property real positionSec: Number(player?.position ?? 0)

    // MPRIS position reads advance, but ordinary playback does not emit updates.
    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    readonly property color accentColor: {
        const id = ((player?.identity ?? "") + " " + (player?.dbusName ?? "")).toLowerCase()
        if (id.includes("spotify")) return root.theme.green
        if (id.includes("firefox")) return root.theme.orange
        if (id.includes("chrom")) return root.theme.blue
        return root.theme.pink
    }

    function playerName(p) {
        if (!p) return "Mídia"
        const id = String(p.identity || p.dbusName || "Mídia")
        if (id.toLowerCase().includes("spotify")) return "Spotify"
        if (id.toLowerCase().includes("firefox")) return "Firefox"
        if (id.toLowerCase().includes("zen")) return "Zen Browser"
        if (id.toLowerCase().includes("chrom")) return "Chromium"
        return id
    }

    function playerIcon(p) {
        if (!p) return ""
        const id = ((p.identity ?? "") + " " + (p.dbusName ?? "")).toLowerCase()
        if (id.includes("spotify")) return ""
        if (id.includes("firefox") || id.includes("zen")) return ""
        if (id.includes("chrom")) return ""
        if (id.includes("vlc")) return "󰕼"
        if (id.includes("mpv")) return "󰐹"
        return ""
    }

    function seekToFraction(fraction) {
        if (!player || lengthSec <= 0) return
        const target = Math.max(0, Math.min(lengthSec, fraction * lengthSec))
        try {
            player.position = target
        } catch (e) {
            try {
                player.setPosition(target)
            } catch (err) {}
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        cardColor: root.theme.backgroundOpaque
        cardClip: true
        frameColor: "transparent"
        Keys.onEscapePressed: root.visible = false

        HoverHandler { id: cardHover }

        // Alpha mask for the rounded ambient blur effect
        Rectangle {
            id: roundedMask
            anchors.fill: parent
            radius: card.radius
            color: "white"
            visible: false
            layer.enabled: true
        }

        Image {
            id: ambientSource
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        // Vibrant ambient artwork glow in the background
        MultiEffect {
            id: ambientBlur
            anchors.fill: parent
            source: ambientSource
            visible: root.artUrl.length > 0
            opacity: 0.35

            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 1.20

            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: roundedMask

            Behavior on opacity {
                enabled: root.theme.qmlAnimationsEnabled
                NumberAnimation { duration: root.theme.motionTransientFadeDuration; easing.type: root.theme.motionEasing }
            }
        }

        // Theme-adaptive glass gradient keeps artwork soft behind the text.
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.theme.withAlpha(
                        root.theme.isLight ? root.theme.surfaceContainerLow : root.theme.heroBackdropStart,
                        0.72
                    )
                }
                GradientStop {
                    position: 0.5
                    color: root.theme.withAlpha(
                        root.theme.isLight ? root.theme.surfaceContainer : root.theme.heroBackdropCenter,
                        0.82
                    )
                }
                GradientStop {
                    position: 1.0
                    color: root.theme.withAlpha(
                        root.theme.isLight ? root.theme.surfaceContainerHigh : root.theme.heroBackdropEnd,
                        0.92
                    )
                }
            }
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.theme.popupInsets.outer
            spacing: root.theme.spacingTokens.xl

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 24
                leadingIcon: root.playerIcon(root.player)
                leadingIconColor: root.accentColor
                iconBoxSize: 22
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.withAlpha(root.theme.pureWhite, titleHovered ? 0.16 : 0.08)
                iconBoxBorderWidth: 1
                iconBoxBorderColor: root.theme.withAlpha(root.theme.pureWhite, titleHovered ? 0.22 : 0.10)
                iconPixelSize: root.theme.iconTokens.smPlus
                title: root.playerName(root.player)
                titlePixelSize: root.theme.typeTokens.body
                titleWeight: Font.DemiBold
                titleInteractive: root.players.length > 1
                onTitleActivated: root.showPlayerList = !root.showPlayerList
                titleAccessory: Component {
                    Text {
                        visible: root.players.length > 1
                        text: root.showPlayerList ? "▴" : "▾"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                    }
                }

                CloseButton {
                    id: closeBtn
                    theme: root.theme
                    buttonSize: 24
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.visible = false
                }
            }

            // Expandable Player Selector Drawer (when clicked):
            // active player as a big colored card, the rest as small grey
            // cards; tapping one promotes it with an animated swap.
            Column {
                id: playerListColumn
                visible: root.showPlayerList && root.players.length > 1
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                Rectangle {
                    id: playerHero
                    width: parent.width
                    height: 66
                    radius: root.theme.radiusMd
                    color: root.theme.withAlpha(root.accentColor, 0.14)
                    border.width: 1
                    border.color: root.accentColor

                    Behavior on color { enabled: root.theme.qmlAnimationsEnabled; ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing } }
                    Behavior on border.color { enabled: root.theme.qmlAnimationsEnabled; ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: root.theme.popupInsets.large
                        anchors.rightMargin: root.theme.popupInsets.large
                        spacing: root.theme.spacingTokens.lg

                        Text {
                            text: root.playerIcon(root.player)
                            color: root.accentColor
                            font.family: root.theme.nerdFontFamily
                            font.pixelSize: root.theme.iconTokens.mediaControl
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 72
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.theme.spacingTokens.micro

                            Text {
                                text: "Tocando agora"
                                color: root.accentColor
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.caption
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: root.playerName(root.player)
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.bodyEmphasis
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: String(root.player?.trackTitle ?? "")
                                visible: text.length > 0
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.body
                                elide: Text.ElideRight
                            }
                        }

                        TablerIcon {
                            width: root.theme.iconTokens.lgPlus
                            height: root.theme.iconTokens.lgPlus
                            iconName: "dashboard-check"
                            iconColor: root.accentColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    NumberAnimation on scale {
                        id: playerSwapAnim
                        from: 0.96
                        to: 1
                        duration: root.theme.motionFast
                        easing.type: root.theme.motionEasing
                        running: false
                    }
                }

                // Keep the delegate model stable while MPRIS player objects
                // are destroyed. Rebinding a JS object array here crashes
                // Qt 6.11 inside Repeater/Instantiator model regeneration.
                Repeater {
                    model: 16

                    delegate: PopupListRow {
                        id: alternatePlayerDelegate
                        theme: root.theme
                        required property int index
                        parent: playerListColumn
                        readonly property var playerData:
                            index < root.otherPlayers.length
                            ? root.otherPlayers[index]
                            : null
                        visible: playerData !== null
                        width: parent.width
                        rowHeight: 34
                        idleColor: root.theme.withAlpha(root.theme.pureWhite, 0.04)
                        hoverColor: root.theme.withAlpha(root.theme.pureWhite, 0.10)
                        idleBorderColor: root.theme.withAlpha(root.theme.pureWhite, 0.08)

                        Behavior on color { enabled: root.theme.qmlAnimationsEnabled; ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing } }
                        leadingIcon: root.playerIcon(alternatePlayerDelegate.playerData)
                        leadingIconColor: root.theme.foreground
                        title: root.playerName(alternatePlayerDelegate.playerData)
                        titlePixelSize: root.theme.typeTokens.subtitle
                        titleColor: root.theme.offWhite
                        subtitle: String(alternatePlayerDelegate.playerData?.trackTitle ?? "")

                        // Tap handling must live in interactionHandlers:
                        // default content is hidden under the standard
                        // layout, so handlers placed there never fire.
                        interactionHandlers: TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                root.playerSelected(alternatePlayerDelegate.playerData)
                                root.showPlayerList = false
                            }
                        }
                    }
                }
            }

            // Hero Section: Album Artwork + Track Information
            Row {
                width: parent.width
                height: 80
                spacing: root.theme.spacingTokens.xl

                // Artwork container
                Rectangle {
                    id: artContainer
                    width: 80
                    height: 80
                    radius: root.theme.radiusMd
                    color: root.theme.glassActiveSurface
                    border.width: 1
                    border.color: root.theme.glassBorder
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Image {
                        id: artwork
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: artwork.status !== Image.Ready
                        color: root.theme.glassPanelSurface

                        TablerIcon {
                            anchors.centerIn: parent
                            width: root.theme.iconTokens.mediaPrimaryControl
                            height: root.theme.iconTokens.mediaPrimaryControl
                            iconName: "bar-music"
                            iconColor: root.theme.foreground
                        }
                    }
                }

                // Track details
                Column {
                    width: parent.width - artContainer.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.theme.spacingTokens.tight

                    Text {
                        width: parent.width
                        text: root.title
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.titleMedium
                        font.weight: Font.Bold
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.artist
                        color: root.accentColor
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.bodyEmphasis
                        font.weight: Font.Medium
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: root.album.length > 0
                        text: root.album
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }
            }

            MediaSeekBar {
                theme: root.theme
                position: root.positionSec
                duration: root.lengthSec
                accent: root.accentColor
                timeColor: root.theme.foreground
                trackHeight: 5
                hitAreaHeight: 16
                thumbSize: 11
                timePixelSize: root.theme.typeTokens.body
                sectionSpacing: root.theme.spacingTokens.xs
                onSeekRequested: function(fraction) { root.seekToFraction(fraction) }
            }

            // Spacious, Centered Media Controls Row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.theme.spacingTokens.xxxl
                height: 46

                // Previous Track
                Rectangle {
                    width: 36
                    height: 36
                    radius: width / 2
                    color: prevHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.14)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.05)
                    border.width: 1
                    border.color: prevHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.20)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.player && root.player.canGoPrevious ? 1 : 0.35

                    TablerIcon {
                        anchors.centerIn: parent
                        width: root.theme.iconTokens.lg
                        height: root.theme.iconTokens.lg
                        iconName: "bar-prev"
                        iconColor: prevHover.hovered ? root.theme.foreground : root.theme.offWhite
                    }

                    HoverHandler { id: prevHover }

                    TapHandler {
                        enabled: root.player && root.player.canGoPrevious
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.player.previous()
                    }
                }

                // Play / Pause Hero Button
                Rectangle {
                    id: heroPlayBtn
                    width: 46
                    height: 46
                    radius: width / 2
                    color: playHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.24)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.15)
                    border.width: 1
                    border.color: playHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.30)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.18)
                    anchors.verticalCenter: parent.verticalCenter
                    scale: heroPlayTap.pressed ? 0.92 : 1.0

                    Behavior on scale {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation { duration: root.theme.motionPress; easing.type: Easing.OutQuad }
                    }

                    TablerIcon {
                        anchors.centerIn: parent
                        width: root.theme.iconTokens.xl
                        height: root.theme.iconTokens.xl
                        iconName: root.player?.isPlaying ? "bar-pause" : "bar-play"
                        iconColor: root.accentColor
                    }

                    HoverHandler { id: playHover }

                    TapHandler {
                        id: heroPlayTap
                        enabled: root.player && root.player.canTogglePlaying
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.player.togglePlaying()
                    }
                }

                // Next Track
                Rectangle {
                    width: 36
                    height: 36
                    radius: width / 2
                    color: nextHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.14)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.05)
                    border.width: 1
                    border.color: nextHover.hovered
                           ? root.theme.withAlpha(root.theme.pureWhite, 0.20)
                           : root.theme.withAlpha(root.theme.pureWhite, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.player && root.player.canGoNext ? 1 : 0.35

                    TablerIcon {
                        anchors.centerIn: parent
                        width: root.theme.iconTokens.lg
                        height: root.theme.iconTokens.lg
                        iconName: "bar-next"
                        iconColor: nextHover.hovered ? root.theme.foreground : root.theme.offWhite
                    }

                    HoverHandler { id: nextHover }

                    TapHandler {
                        enabled: root.player && root.player.canGoNext
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.player.next()
                    }
                }
            }
        }

        // Keep the artwork and gradient beneath a clean, theme-matched frame.
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: root.theme.barIslandBorder
            z: 100
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
