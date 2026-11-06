// LEGADO: componente não montado no shell atual (substituído por bar/MediaIsland.qml e bar/QuickMediaPlayer.qml).
import QtQuick
import qs.services

Rectangle {
    id: root
    required property var theme

    readonly property var players: MediaState.players
    readonly property var player: MediaState.player
    readonly property string title: player ? String(player.trackTitle ?? "").trim() : ""
    property bool openedByHover: false

    visible: player !== null && title.length > 0
    width: 31
    height: root.theme ? root.theme.pillHeight : 25
    radius: root.theme ? root.theme.pillRadius : 6
    color: mouseArea.containsMouse ? root.theme.pillBackgroundHover : root.theme.pillBackground
    border.width: 1
    border.color: mouseArea.containsMouse ? root.theme.pillBorderHover : root.theme.pillBorder

    Text {
        anchors.centerIn: parent
        text: ""
        color: root.player && root.player.isPlaying ? root.theme.pink : root.theme.offWhite
        font.family: root.theme.nerdFontFamily
        font.pixelSize: root.theme.iconTokens.lg
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            closeTimer.stop()
            if (!mediaPopup.visible) openTimer.start()
        }

        onExited: {
            openTimer.stop()
            if (root.openedByHover) closeTimer.start()
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                openTimer.stop()
                closeTimer.stop()
                // Clicking a hover preview pins it open with focus
                // instead of toggling it closed.
                const opening = root.openedByHover ? true : !mediaPopup.visible
                root.openedByHover = false
                mediaPopup.visible = opening
            }
        }

        onWheel: function(wheel) {
            if (!root.player) return
            if (wheel.angleDelta.y > 0 && root.player.canGoNext)
                root.player.next()
            else if (wheel.angleDelta.y < 0 && root.player.canGoPrevious)
                root.player.previous()
        }
    }

    Timer {
        id: openTimer
        interval: 250
        onTriggered: {
            if (!mouseArea.containsMouse || mediaPopup.visible) return
            root.openedByHover = true
            mediaPopup.visible = true
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: {
            if (root.openedByHover && !mouseArea.containsMouse && !mediaPopup.containsPointer)
                mediaPopup.visible = false
        }
    }

    MediaPopup {
        id: mediaPopup
        theme: root.theme
        target: root
        hoverPreview: root.openedByHover
        player: root.player
        players: root.players.filter(p => p && (p.isPlaying || String(p.trackTitle ?? "").trim().length > 0))
        onPlayerSelected: function(p) { MediaState.selectPlayer(p) }
        onContainsPointerChanged: {
            if (containsPointer) closeTimer.stop()
            else if (root.openedByHover && !mouseArea.containsMouse) closeTimer.start()
        }
        onVisibleChanged: {
            if (!visible) root.openedByHover = false
        }
    }
}
