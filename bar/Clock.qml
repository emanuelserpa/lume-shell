import QtQuick
import QtQuick.Window
import Quickshell
import qs.components
import qs.services

Item {
    id: root
    required property var theme
    property bool plain: true
    property bool active: dashboardPopup.visible

    signal toggleDashboardRequested()

    implicitWidth: pill.implicitWidth
    implicitHeight: root.theme.pillHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // SystemClock sleeps until the next minute boundary on the monotonic
    // clock, which does not advance during suspend: after resume it can
    // stay stale for the whole suspended duration. Periodically restart
    // its internal timer so it resyncs shortly after resume.
    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: {
            clock.enabled = false
            clock.enabled = true
        }
    }

    Connections {
        target: WeatherState
        function onToggleDashboardRequested(targetWindow) {
            if (targetWindow === root.Window.window)
                dashboardPopup.toggle()
        }
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        highlighted: root.active
        textColor: root.theme.accent
        text: ""
        implicitWidth: clockContent.implicitWidth + 10

        Row {
            id: clockContent
            anchors.centerIn: parent
            spacing: root.theme.spacingTokens.xs
            TablerIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: root.theme.barIconSize; height: width
                iconName: "bar-calendar"; iconColor: pill.textColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "dd/MM")
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.iconTokens.lg
                font.weight: Font.DemiBold
                color: pill.textColor
            }
            Item { width: root.theme.spacingTokens.xs; height: 1 }
            TablerIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: root.theme.barIconSize; height: width
                iconName: "bar-clock"; iconColor: pill.textColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.iconTokens.lg
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: pill.textColor
            }
        }

        tooltipText: "Calendário e clima"

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.toggleDashboardRequested()
                dashboardPopup.toggle()
            } else if (mouse.button === Qt.RightButton) {
                IdleState.inhibited = !IdleState.inhibited
            }
        }
    }

    CenterDashboardPopup {
        id: dashboardPopup
        theme: root.theme
        target: root.parent ? root.parent : root
    }
}
