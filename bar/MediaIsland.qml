import QtQuick
import qs.components
import qs.services

Item {
    id: root

    required property var theme

    readonly property var mediaPlayers: MediaState.players.filter(player =>
        player && (player.isPlaying || String(player.trackTitle ?? "").trim().length > 0)
    )
    readonly property var currentPlayer: MediaState.player
        && mediaPlayers.some(player => player === MediaState.player)
        ? MediaState.player
        : (mediaPlayers.length > 0 ? mediaPlayers[0] : null)
    readonly property string trackTitle: String(currentPlayer?.trackTitle ?? "").trim()
    readonly property string artist: currentPlayer ? MediaState.displayArtist(currentPlayer) : ""
    readonly property string artUrl: String(currentPlayer?.trackArtUrl ?? "").trim()
    readonly property real lengthSec: Number(currentPlayer?.length ?? 0)
    readonly property real positionSec: Number(currentPlayer?.position ?? 0)
    readonly property color playerAccent: {
        const id = ((currentPlayer?.identity ?? "") + " " + (currentPlayer?.dbusName ?? "")).toLowerCase()
        if (id.includes("spotify")) return theme.green
        if (id.includes("firefox")) return theme.orange
        if (id.includes("chrom")) return theme.blue
        return theme.pink
    }

    function playerIcon(player) {
        const id = ((player?.identity ?? "") + " " + (player?.dbusName ?? "")).toLowerCase()
        if (id.includes("spotify")) return ""
        if (id.includes("firefox") || id.includes("zen")) return ""
        if (id.includes("chrom")) return ""
        if (id.includes("vlc")) return "󰕼"
        if (id.includes("mpv")) return "󰐹"
        return ""
    }
    readonly property real progressFraction: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0

    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.currentPlayer !== null && root.currentPlayer.isPlaying
        onTriggered: if (root.currentPlayer) root.currentPlayer.positionChanged()
    }

    visible: currentPlayer !== null
    width: implicitWidth
    height: implicitHeight
    implicitWidth: currentPlayer !== null ? contentRow.implicitWidth + theme.spacingTokens.md : 0
    implicitHeight: theme.barIslandHeight

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: root.theme.barIslandRadius
        color: "transparent"
        border.width: 0
        clip: true

        HoverHandler {
            id: pillHover
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!playerSelector.pointerInside)
                    mediaPopup.visible = !mediaPopup.visible
            }
        }

        Row {
            id: contentRow
            z: 2
            height: parent.height - 4
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            anchors.left: parent.left
            anchors.leftMargin: root.theme.spacingTokens.xs
            spacing: root.theme.spacingTokens.sm

            Item { width: 2; height: 1 }

            // Album Artwork with smooth rounded corners
            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: root.theme.withAlpha(root.theme.surfaceForeground, 0.08)
                    clip: true

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.artUrl
                        sourceSize.width: 36
                        sourceSize.height: 36
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: root.artUrl.length > 0 && status === Image.Ready
                    }

                    // Use the player identity when artwork is unavailable.
                    Text {
                        anchors.centerIn: parent
                        visible: !coverImage.visible
                        text: root.playerIcon(root.currentPlayer)
                        color: root.playerAccent
                        font.family: root.theme.nerdFontFamily
                        font.pixelSize: 13
                    }

                    // Subtle border overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: root.theme.withAlpha(root.theme.outline, 0.18)
                    }
                }
            }

            // Live mini audio visualizer bars (anchored to bottom, growing upwards)
            Item {
                width: 10
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: Boolean(root.currentPlayer?.isPlaying)

                Row {
                    anchors.bottom: parent.bottom
                    spacing: 2

                    Item {
                        width: 2
                        height: 12
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 2
                            radius: 1
                            color: root.playerAccent
                            SequentialAnimation on height {
                                running: Boolean(root.currentPlayer?.isPlaying)
                                loops: Animation.Infinite
                                NumberAnimation { from: 3; to: 11; duration: 400; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 11; to: 3; duration: 400; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    Item {
                        width: 2
                        height: 12
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 2
                            radius: 1
                            color: root.playerAccent
                            SequentialAnimation on height {
                                running: Boolean(root.currentPlayer?.isPlaying)
                                loops: Animation.Infinite
                                NumberAnimation { from: 10; to: 4; duration: 320; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 4; to: 10; duration: 320; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    Item {
                        width: 2
                        height: 12
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 2
                            radius: 1
                            color: root.playerAccent
                            SequentialAnimation on height {
                                running: Boolean(root.currentPlayer?.isPlaying)
                                loops: Animation.Infinite
                                NumberAnimation { from: 4; to: 12; duration: 480; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 12; to: 4; duration: 480; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }
            }

            // Track title & artist with intelligent adaptive width
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                width: Math.min(180, Math.max(90, Math.max(titleText.implicitWidth, artistText.implicitWidth)))

                Text {
                    id: titleText
                    width: parent.width
                    text: root.trackTitle
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    id: artistText
                    width: parent.width
                    text: root.artist
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.caption
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Media control buttons (Previous, Play/Pause, Next)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // Previous track (reveals on hover)
                Item {
                    width: pillHover.hovered ? 20 : 0
                    height: 20
                    opacity: pillHover.hovered ? 1 : 0
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: root.theme.stateLayer(root.theme.surfaceForeground,
                                                     prevMouse.containsMouse ? "dragged" : "none")

                        TablerIcon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            iconName: "bar-prev"
                            iconColor: root.theme.foreground
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPlayer?.previous()
                        }
                    }
                }

                // Play / Pause button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: root.theme.stateLayer(root.theme.surfaceForeground,
                                                 playMouse.containsMouse ? "dragged" : "none")
                    anchors.verticalCenter: parent.verticalCenter

                    TablerIcon {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        iconName: root.currentPlayer?.isPlaying ? "bar-pause" : "bar-play"
                        iconColor: root.theme.foreground
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPlayer?.togglePlaying()
                    }
                }

                // Next track (reveals on hover)
                Item {
                    width: pillHover.hovered ? 20 : 0
                    height: 20
                    opacity: pillHover.hovered ? 1 : 0
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: root.theme.stateLayer(root.theme.surfaceForeground,
                                                     nextMouse.containsMouse ? "dragged" : "none")

                        TablerIcon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            iconName: "bar-next"
                            iconColor: root.theme.foreground
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPlayer?.next()
                        }
                    }
                }
            }

            MediaPlayerDots {
                id: playerSelector
                theme: root.theme
                players: root.mediaPlayers
                selectedPlayer: root.currentPlayer
                accent: root.playerAccent
                compact: true
                visible: root.mediaPlayers.length > 1
                anchors.verticalCenter: parent.verticalCenter
                onPlayerSelected: function(selected) { MediaState.selectPlayer(selected) }
            }

            Item { width: 2; height: 1 }
        }

        // Sleek progress line at the bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1.5
            radius: 1
            color: root.theme.withAlpha(root.theme.surfaceForeground, 0.10)
            visible: root.lengthSec > 0

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * root.progressFraction
                color: root.playerAccent
                opacity: 0.75
            }
        }

    }

    MediaPopup {
        id: mediaPopup
        theme: root.theme
        target: root
        player: root.currentPlayer
        players: root.mediaPlayers
        onPlayerSelected: function(selected) { MediaState.selectPlayer(selected) }
    }
}
