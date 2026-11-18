import QtQuick
import QtQuick.Window
import QtTest
import "../../bar" as Bar

TestCase {
    id: testCase
    name: "MediaPlayerDots"
    when: windowShown

    readonly property var testPlayers: [
        ({ identity: "Spotify", dbusName: "org.mpris.MediaPlayer2.spotify" }),
        ({ identity: "Firefox", dbusName: "org.mpris.MediaPlayer2.firefox" })
    ]
    property var activePlayers: testPlayers
    property var currentPlayer: testPlayers[0]
    property var selectedBySignal: null

    QtObject {
        id: testTheme
        readonly property color primary: "#80a0ff"
        readonly property color surfaceVariantForeground: "#a0a0a0"
        readonly property bool qmlAnimationsEnabled: false
        readonly property int motionFast: 120
        readonly property int motionEasing: Easing.OutCubic

        function withAlpha(colorValue, alpha) {
            return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, alpha)
        }
    }

    Window {
        id: testWindow
        width: 240
        height: 48
        visible: true

        Item {
            anchors.fill: parent

            Bar.MediaPlayerDots {
                id: dots
                width: parent.width
                theme: testTheme
                players: testCase.activePlayers
                selectedPlayer: testCase.currentPlayer
                onPlayerSelected: function(player) {
                    testCase.selectedBySignal = player
                    testCase.currentPlayer = player
                }
            }
        }
    }

    function init() {
        activePlayers = testPlayers
        currentPlayer = testPlayers[0]
        selectedBySignal = null
    }

    function test_activePlayerHasSelectedDot() {
        compare(dots.players.length, 2)
        verify(dots.visible)
        compare(dots.selectedIndex, 0)
    }

    function test_tappingDotChangesSelectedPlayer() {
        const secondDot = findChild(dots, "media-player-dot-1")
        verify(secondDot !== null)

        mouseClick(secondDot, secondDot.width / 2, secondDot.height / 2)

        compare(selectedBySignal, testPlayers[1])
        compare(dots.selectedIndex, 1)
    }

    function test_singlePlayerHidesTheIndicator() {
        activePlayers = [testPlayers[0]]
        verify(!dots.visible)
        compare(dots.height, 0)
    }
}
