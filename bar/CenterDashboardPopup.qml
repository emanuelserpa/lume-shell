pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.components
import qs.services

PopupWindow {

    id: root

    required property var theme
    required property Item target

    // Weather properties
    property var weatherData: WeatherState.weatherData
    property var citiesData: WeatherState.citiesData

    readonly property string holidayRegion: {
        const cities = root.citiesData?.cities ?? []
        const selectedId = root.citiesData?.selected
        const weatherCity = String(root.weatherData?.city ?? "").toLowerCase()
        let city = cities.find(function(item) {
            return item.id === selectedId && String(item.region ?? "").length > 0
        })
        if (!city && weatherCity.length > 0) {
            city = cities.find(function(item) {
                return String(item.name ?? "").toLowerCase() === weatherCity
            })
        }
        return String(city?.region ?? "")
    }

    // Weather signals
    signal refreshWeatherRequested()
    signal citySelected(string id)
    signal cityRemoved(string id)
    signal cityAdded(string id, string name, string region, string country,
                     real latitude, real longitude)

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    readonly property real screenWidth: target?.Screen?.width ?? 1600
    readonly property real screenHeight: target?.Screen?.height ?? 900
    readonly property real maxAllowedWidth: Math.max(360, screenWidth - 32)
    readonly property real maxAllowedHeight: Math.min(screenHeight - 16, Math.max(300, screenHeight - 60))

    readonly property real availableContentWidth: Math.max(0, card.width - 20)
    readonly property real targetColumnsWidth: Math.max(0, availableContentWidth - 10)
    readonly property bool needsScroll: availableContentWidth < 650

    // Weather and calendar retain their minimum widths on compact displays.
    readonly property real col1Width: needsScroll ? 320 : Math.round(targetColumnsWidth * (334 / 658))
    readonly property real col2Width: needsScroll ? 310 : Math.max(260, targetColumnsWidth - col1Width)

    readonly property int activePageIndex: {
        if (!needsScroll || flickable.contentWidth <= flickable.width) return 1
        const maxScroll = Math.max(1, flickable.contentWidth - flickable.width)
        const progress = flickable.contentX / maxScroll
        return progress < 0.5 ? 0 : 1
    }

    implicitWidth: Math.min(700, maxAllowedWidth)
    implicitHeight: Math.min(needsScroll ? 438 : 426, maxAllowedHeight)

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    function toggle() {

        root.visible = !root.visible
    }

    function moveToPage(x) {
        if (root.theme.qmlAnimationsEnabled) {
            scrollAnim.to = x
            scrollAnim.restart()
        } else {
            flickable.contentX = x
        }
    }

    onVisibleChanged: {
        WeatherState.setDashboardOpen(root.target ? root.target.Window.window : null, visible)
        if (visible) {
            card.forceActiveFocus()
            openRefresh.restart()
        } else {
            openRefresh.stop()
            weatherCard.addMode = false
            weatherCard.cityMenuOpen = false
            weatherCard.searchResults = []
        }
    }

    // Defer rebuild + backend refreshes off the show frame so the
    // enter animation runs without a hitch.
    Timer {
        id: openRefresh
        interval: 120
        repeat: false
        onTriggered: {
            if (!root.visible) return
            calendarCard.resetDate()
            WeatherState.refreshAll()
            root.refreshWeatherRequested()
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        Keys.onEscapePressed: root.visible = false

        Keys.onLeftPressed: function(event) {
            if (root.needsScroll && root.activePageIndex > 0) {
                const targetIdx = root.activePageIndex - 1
                const pages = [
                    0,
                    Math.max(0, flickable.contentWidth - flickable.width)
                ]
                root.moveToPage(pages[targetIdx])
                event.accepted = true
            }
        }

        Keys.onRightPressed: function(event) {
            if (root.needsScroll && root.activePageIndex < 1) {
                const targetIdx = root.activePageIndex + 1
                const pages = [
                    0,
                    Math.max(0, flickable.contentWidth - flickable.width)
                ]
                root.moveToPage(pages[targetIdx])
                event.accepted = true
            }
        }

        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.standard
            anchors.bottomMargin: root.needsScroll ? 22 : 10
            contentWidth: rowLayout.width
            contentHeight: rowLayout.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.needsScroll

            WheelKinetic {
                scrollTarget: flickable
                scrollOrientation: Qt.Horizontal
            }

            NumberAnimation {
                id: scrollAnim
                target: flickable
                property: "contentX"
                duration: root.theme.motionLayout
                easing.type: Easing.OutCubic
            }

            Row {
                id: rowLayout
                spacing: root.theme.spacingTokens.lg
                height: flickable.height

                // Clima & cidades
                WeatherCard {
                    id: weatherCard
                    width: root.col1Width
                    height: parent.height
                    theme: root.theme
                    weatherData: root.weatherData
                    citiesData: root.citiesData

                    onRefreshRequested: {
                        WeatherState.refreshAll()
                        root.refreshWeatherRequested()
                    }
                    onCitySelected: function(id) {
                        WeatherState.selectCity(id)
                        root.citySelected(id)
                    }
                    onCityRemoved: function(id) {
                        WeatherState.removeCity(id)
                        root.cityRemoved(id)
                    }
                    onCityAdded: function(id, name, region, country, lat, lon) {
                        WeatherState.addCity(id, name, region, country, lat, lon)
                        root.cityAdded(id, name, region, country, lat, lon)
                    }
                }

                // Calendário e monitor de sistema
                CalendarCard {
                    id: calendarCard
                    width: root.col2Width
                    height: parent.height
                    theme: root.theme
                    holidayRegion: root.holidayRegion

                    onCloseRequested: {
                        root.visible = false
                    }
                }

            }
        }

        // Indicator dots/pills for compact screen widths
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.theme.popupInsets.small
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.theme.spacingTokens.sm
            visible: root.needsScroll

            Repeater {
                model: [
                    { name: "Clima", targetX: 0 },
                    { name: "Calendário", targetX: Math.max(0, flickable.contentWidth - flickable.width) }
                ]

                delegate: Rectangle {
                    id: dashboardPageDelegate
                    required property var modelData
                    required property int index

                    width: root.activePageIndex === index ? 22 : 7
                    height: 7
                    radius: height / 2
                    color: root.activePageIndex === index ? root.theme.accent : root.theme.surfaceVariant
                    opacity: root.activePageIndex === index ? 1.0 : 0.5

                    Behavior on width { enabled: root.theme.qmlAnimationsEnabled; NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing } }
                    Behavior on opacity { enabled: root.theme.qmlAnimationsEnabled; NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.moveToPage(dashboardPageDelegate.modelData.targetX)
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }

    Shortcut {
        sequence: "Left"
        enabled: root.visible && !root.needsScroll && !weatherCard.cityMenuOpen
        onActivated: calendarCard.prevMonth()
    }

    Shortcut {
        sequence: "Right"
        enabled: root.visible && !root.needsScroll && !weatherCard.cityMenuOpen
        onActivated: calendarCard.nextMonth()
    }

    Shortcut {
        sequence: "["
        enabled: root.visible && !weatherCard.cityMenuOpen
        onActivated: calendarCard.prevMonth()
    }

    Shortcut {
        sequence: "]"
        enabled: root.visible && !weatherCard.cityMenuOpen
        onActivated: calendarCard.nextMonth()
    }

    Shortcut {
        sequence: "T"
        enabled: root.visible && !weatherCard.cityMenuOpen
        onActivated: calendarCard.resetDate()
    }

    Shortcut {
        sequence: "W"
        enabled: root.visible && !weatherCard.cityMenuOpen
        onActivated: calendarCard.startOnMonday = !calendarCard.startOnMonday
    }

    Shortcut {
        sequence: "R"
        enabled: root.visible && !weatherCard.cityMenuOpen
        onActivated: {
            WeatherState.refreshAll()
            root.refreshWeatherRequested()
        }
    }
}
