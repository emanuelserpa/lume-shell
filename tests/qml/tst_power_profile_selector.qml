import QtQuick
import QtQuick.Window
import QtTest
import "../../components" as Components

TestCase {
    id: testCase
    name: "PowerProfileSelector"
    when: windowShown

    property string requestedProfile: ""

    QtObject {
        id: testTheme
        readonly property color accent: "#89b4fa"
        readonly property color green: "#a6e3a1"
        readonly property color yellow: "#f9e2af"
        readonly property color offWhite: "#bac2de"
        readonly property color surfaceVariantForeground: "#a6adc8"
        readonly property color glassHoverSurface: "#45475a"
        readonly property color glassCardSurface: "#313244"
        readonly property color pillBorderHover: "#585b70"
        readonly property color borderRegular: "#45475a"
        readonly property bool qmlAnimationsEnabled: false
        readonly property int motionFast: 120
        readonly property int motionEasing: Easing.OutCubic
        readonly property int radiusSm: 8
        readonly property string fontFamily: "Noto Sans"
        readonly property var spacingTokens: ({ "xs": 4, "sm": 6 })
        readonly property var iconTokens: ({ "md": 12 })
        readonly property var typeTokens: ({ "meta": 9 })

        function withAlpha(colorValue, alpha) {
            return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, alpha)
        }
    }

    Window {
        id: testWindow
        width: 316
        height: 48
        visible: true

        Components.PowerProfileSelector {
            id: selector
            width: 300
            theme: testTheme
            activeProfile: "extra-low-power"
            profiles: [
                { id: "extra-low-power", label: "Ultra Eco", icon: "leaf" },
                { id: "power-saver", label: "Economia" },
                { id: "balanced", label: "Equilibrado" },
                { id: "performance", label: "Desempenho" }
            ]
            onProfileRequested: function(profileId) {
                testCase.requestedProfile = profileId
            }
        }
    }

    function test_leafIconAndLabelSitSideBySideWithoutOverlap() {
        const icon = findChild(selector, "")
        verify(selector.width === 300)
        // Find the first button's Row children: TablerIcon and Text.
        const firstBtn = selector.children[0]
        verify(firstBtn !== null && firstBtn !== undefined)
        const row = firstBtn.children[0]
        verify(row !== null && row !== undefined)
        const leafIcon = row.children[0]
        const labelText = row.children[1]
        verify(leafIcon.visible)
        verify(labelText.visible)
        verify(leafIcon.width > 0)
        verify(labelText.width > 0)
        verify(leafIcon.x + leafIcon.width < labelText.x)
    }

    function test_clickingButtonEmitsProfileRequested() {
        testCase.requestedProfile = ""
        const thirdBtn = selector.children[2]
        mouseClick(thirdBtn, thirdBtn.width / 2, thirdBtn.height / 2)
        compare(testCase.requestedProfile, "balanced")
    }
}
