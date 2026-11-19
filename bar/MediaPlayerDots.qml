pragma ComponentBehavior: Bound

import QtQuick

// shared-ui-guard: allow — the Android-style page indicator is an intentional bespoke control.
Item {
    id: root

    required property var theme
    property var players: []
    property var selectedPlayer: null
    property color accent: theme.primary
    property bool compact: false
    property bool indicatePlaying: false
    signal playerSelected(var player)

    readonly property bool pointerInside: pointerHover.hovered

    readonly property int selectedIndex: {
        const list = players ?? []
        const selectedKey = playerKey(selectedPlayer)
        if (!selectedKey) return -1
        for (let i = 0; i < list.length; i++) {
            if (playerKey(list[i]) === selectedKey) return i
        }
        return -1
    }

    function playerKey(player) {
        return String(player?.dbusName || player?.identity || "")
    }

    visible: (players?.length ?? 0) > 1
    width: compact ? Math.min(players?.length ?? 0, 16) * 14 : (parent ? parent.width : 0)
    height: visible ? (compact ? 20 : 24) : 0

    HoverHandler {
        id: pointerHover
    }

    Row {
        anchors.centerIn: parent

        Repeater {
            // Keep this fixed pool: MPRIS proxies can be destroyed while the
            // player list changes, and a dynamic object model can crash Qt.
            model: 16

            delegate: Item {
                id: dotDelegate
                required property int index
                objectName: "media-player-dot-" + index
                readonly property var playerData: index < (root.players?.length ?? 0)
                    ? root.players[index]
                    : null
                readonly property bool selected: index === root.selectedIndex
                readonly property bool playingInactive:
                    root.indicatePlaying && !selected && Boolean(playerData?.isPlaying)
                property real playingPulse: 0.32
                property real playingScale: 0.94
                width: playerData !== null ? (root.compact ? 14 : 28) : 0
                height: root.compact ? 20 : 24
                activeFocusOnTab: playerData !== null
                Accessible.role: Accessible.Button
                Accessible.name: playerData
                    ? qsTr("Player %1 de %2: %3").arg(index + 1).arg(root.players.length)
                          .arg(String(playerData.identity || playerData.dbusName || "Mídia"))
                    : ""

                Keys.onLeftPressed: function(event) {
                    if (index > 0) root.playerSelected(root.players[index - 1])
                    event.accepted = true
                }
                Keys.onRightPressed: function(event) {
                    if (index + 1 < root.players.length)
                        root.playerSelected(root.players[index + 1])
                    event.accepted = true
                }
                Keys.onReturnPressed: root.playerSelected(playerData)
                Keys.onSpacePressed: root.playerSelected(playerData)

                SequentialAnimation {
                    running: dotDelegate.playingInactive && root.theme.qmlAnimationsEnabled
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation {
                            target: dotDelegate
                            property: "playingPulse"
                            to: 0.58
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: dotDelegate
                            property: "playingScale"
                            to: 1.08
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: dotDelegate
                            property: "playingPulse"
                            to: 0.32
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: dotDelegate
                            property: "playingScale"
                            to: 0.94
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: dotDelegate.selected
                        ? (root.compact ? 10 : 17)
                        : (root.compact ? 4 : 6)
                    height: root.compact ? 5 : 6
                    radius: height / 2
                    color: dotDelegate.selected
                        ? root.accent
                        : root.theme.withAlpha(root.theme.surfaceVariantForeground, 0.65)
                    opacity: dotDelegate.playingInactive ? dotDelegate.playingPulse : 1
                    scale: dotDelegate.playingInactive ? dotDelegate.playingScale : 1

                    Behavior on width {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation {
                            duration: root.theme.motionFast
                            easing.type: root.theme.motionEasing
                        }
                    }
                    Behavior on color {
                        enabled: root.theme.qmlAnimationsEnabled
                        ColorAnimation {
                            duration: root.theme.motionFast
                            easing.type: root.theme.motionEasing
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: dotDelegate.activeFocus ? 1 : 0
                    border.color: root.theme.primary
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: dotDelegate.playerData !== null
                    onTapped: root.playerSelected(dotDelegate.playerData)
                }
            }
        }
    }
}
