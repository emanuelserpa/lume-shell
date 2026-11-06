pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.components
import qs.services

Rectangle {
    id: root

    required property var theme
    property var player: null
    property var players: []
    property bool showPlayers: false
    signal playerSelected(var player)

    readonly property string title: String(player?.trackTitle ?? "").trim() || "Sem título"
    readonly property string artist: player ? MediaState.displayArtist(player) : "Artista desconhecido"
    readonly property string album: String(player?.trackAlbum ?? "").trim()
    readonly property string artUrl: String(player?.trackArtUrl ?? "").trim()
    readonly property real lengthSec: Number(player?.length ?? 0)
    readonly property real positionSec: Number(player?.position ?? 0)
    readonly property color accentColor: {
        const id = ((player?.identity ?? "") + " " + (player?.dbusName ?? "")).toLowerCase()
        if (id.includes("spotify")) return theme.green
        if (id.includes("firefox")) return theme.orange
        if (id.includes("chrom")) return theme.blue
        return theme.pink
    }
    readonly property var otherPlayers: (players ?? []).filter(p => p !== player)

    width: parent ? parent.width : 0
    height: contentColumn.implicitHeight + theme.popupInsets.compactPlus * 2
    implicitHeight: height
    radius: theme.radiusXl
    color: theme.backgroundOpaque
    border.width: 1
    border.color: theme.glassBorder
    clip: true

    onPlayerChanged: showPlayers = false

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
        } catch (error) {
            try { player.setPosition(target) } catch (ignored) {}
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
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

    MultiEffect {
        anchors.fill: parent
        source: ambientSource
        visible: root.artUrl.length > 0
        opacity: 0.22
        blurEnabled: true
        blur: 0.75
        blurMax: 28
        saturation: 0.85
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: roundedMask
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.theme.mediaArtworkOverlay
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: root.theme.popupInsets.compactPlus
        spacing: root.theme.spacingTokens.xs

        Item {
        width: parent.width
        height: 24

        PopupListRow {
            id: currentPlayerRow
            anchors.fill: parent
            theme: root.theme
            rowHeight: 24
            cornerRadius: root.theme.radiusMd
            cursorShape: root.otherPlayers.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            leadingIcon: root.playerIcon(root.player)
            leadingIconColor: root.accentColor
            leadingIconPixelSize: root.theme.iconTokens.lg
            title: root.playerName(root.player)
            titlePixelSize: root.theme.typeTokens.body
            idleColor: "transparent"
            idleBorderWidth: 0
            subtitle: ""
            subtitlePixelSize: root.theme.typeTokens.meta

            trailing: Component {
                Text {
                    visible: root.otherPlayers.length > 0
                    text: root.showPlayers ? "▴" : "▾"
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                }
            }
        }

        TapHandler {
            enabled: root.otherPlayers.length > 0
            onTapped: root.showPlayers = !root.showPlayers
        }
    }

    Column {
        visible: root.showPlayers && root.otherPlayers.length > 0
        width: parent.width
        spacing: root.theme.spacingTokens.micro

        Repeater {
            // Keep the model stable while MPRIS player objects are replaced.
            model: 16

            delegate: Item {
                id: playerDelegate
                required property int index
                readonly property var playerData: index < root.otherPlayers.length
                    ? root.otherPlayers[index]
                    : null
                visible: playerData !== null
                width: parent.width
                height: visible ? 34 : 0

                PopupListRow {
                    anchors.fill: parent
                    theme: root.theme
                    rowHeight: 34
                    cornerRadius: root.theme.radiusSm
                    cursorShape: Qt.PointingHandCursor
                    leadingIcon: root.playerIcon(playerDelegate.playerData)
                    leadingIconColor: root.theme.surfaceVariantForeground
                    leadingIconPixelSize: root.theme.iconTokens.md
                    title: root.playerName(playerDelegate.playerData)
                    titlePixelSize: root.theme.typeTokens.body
                    subtitle: String(playerDelegate.playerData?.trackTitle ?? "")
                    subtitlePixelSize: root.theme.typeTokens.meta
                }

                TapHandler {
                    enabled: playerDelegate.playerData !== null
                    onTapped: {
                        root.playerSelected(playerDelegate.playerData)
                        root.showPlayers = false
                    }
                }
            }
        }
    }

    Row {
        width: parent.width
        height: 48
        spacing: root.theme.spacingTokens.sm

        Rectangle {
            width: 48
            height: 48
            radius: root.theme.radiusMd
            color: root.theme.glassActiveSurface
            border.width: 1
            border.color: root.theme.glassBorderSubtle
            clip: true

            Image {
                id: artwork
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            TablerIcon {
                anchors.centerIn: parent
                visible: artwork.status !== Image.Ready
                width: root.theme.iconTokens.xl
                height: root.theme.iconTokens.xl
                iconName: "bar-music"
                iconColor: root.accentColor
            }
        }

        Column {
            width: Math.max(0, parent.width - 48 - parent.spacing - transportControls.implicitWidth - root.theme.spacingTokens.sm)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacingTokens.micro

            Text {
                width: parent.width
                text: root.title
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.body
                font.weight: Font.DemiBold
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.album.length > 0 ? root.artist + " · " + root.album : root.artist
                color: root.theme.surfaceVariantForeground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                elide: Text.ElideRight
            }
        }

        Row {
            id: transportControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.theme.spacingTokens.micro

            Repeater {
                model: [
                    { tablerIcon: "bar-prev", enabled: Boolean(root.player?.canGoPrevious), action: "previous" },
                    { tablerIcon: root.player?.isPlaying ? "bar-pause" : "bar-play", enabled: Boolean(root.player?.canTogglePlaying), action: "toggle" },
                    { tablerIcon: "bar-next", enabled: Boolean(root.player?.canGoNext), action: "next" }
                ]

                delegate: Rectangle {
                    id: transportButton
                    required property var modelData
                    readonly property bool isPrimary: modelData.action === "toggle"
                    width: isPrimary ? 30 : 24
                    height: isPrimary ? 30 : 24
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: isPrimary
                        ? (transportHover.hovered ? root.accentColor : root.theme.withAlpha(root.accentColor, 0.24))
                        : (transportHover.hovered ? root.theme.glassHoverSurface : "transparent")
                    opacity: modelData.enabled ? 1 : 0.38

                    TablerIcon {
                        anchors.centerIn: parent
                        width: transportButton.isPrimary
                            ? root.theme.iconTokens.md
                            : root.theme.iconTokens.smPlus
                        height: width
                        iconName: transportButton.modelData.tablerIcon
                        iconColor: transportButton.isPrimary && transportHover.hovered
                            ? root.theme.background
                            : root.theme.foreground
                    }

                    HoverHandler {
                        id: transportHover
                        enabled: transportButton.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: transportButton.modelData.enabled
                        onTapped: {
                            if (transportButton.modelData.action === "previous") root.player.previous()
                            else if (transportButton.modelData.action === "next") root.player.next()
                            else root.player.togglePlaying()
                        }
                    }
                }
            }
        }
    }

    MediaSeekBar {
        visible: root.lengthSec > 0
        theme: root.theme
        position: root.positionSec
        duration: root.lengthSec
        accent: root.accentColor
        timeColor: root.theme.surfaceVariantForeground
        trackHeight: 4
        hitAreaHeight: 11
        timePixelSize: root.theme.typeTokens.meta
        sectionSpacing: root.theme.spacingTokens.micro
        onSeekRequested: function(fraction) { root.seekToFraction(fraction) }
    }
}
}
