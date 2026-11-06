import QtQuick
import QtQuick.Window
import qs.components
import qs.services

Item {
    id: root
    required property var theme
    property bool plain: false
    property bool active: WeatherState.activeWindow !== null
                          && WeatherState.activeWindow === Window.window

    readonly property var weatherData: WeatherState.weatherData
    readonly property var citiesData: WeatherState.citiesData

    implicitWidth: pill.visible ? pill.implicitWidth : 0
    implicitHeight: root.theme ? root.theme.pillHeight : 25

    signal cityChanged()
    signal toggleDashboardRequested()

    function refreshAll() {
        WeatherState.refreshAll()
    }

    function selectCity(id) {
        WeatherState.selectCity(id)
    }

    function removeCity(id) {
        WeatherState.removeCity(id)
    }

    function addCity(id, name, region, country, latitude, longitude) {
        WeatherState.addCity(id, name, region, country, latitude, longitude)
    }

    function cycleCity(direction) {
        WeatherState.cycleCity(direction)
    }

    Connections {
        target: WeatherState
        function onCityChanged() {
            root.cityChanged()
        }
    }

    Pill {
        id: pill
        anchors.fill: parent
        visible: WeatherState.hasWeatherText
        theme: root.theme
        plain: root.plain
        highlighted: root.active
        text: String(root.weatherData?.temperature ?? "--") + "°C"
        tablerIcon: {
            const icons = { "󰖙": "sun", "󰖔": "moon", "󰖕": "cloud-sun",
                            "󰖐": "cloud", "󰖖": "rain", "󰖗": "rain",
                            "󰙾": "storm", "󰖘": "snow", "󰖑": "fog" }
            return "bar-" + (icons[root.weatherData?.icon] ?? "cloud")
        }
        iconSize: root.theme.barIconSize
        fontFamily: root.theme.fontFamily
        fontPixelSize: root.theme.iconTokens.lg
        tooltipText: {
            if (!root.weatherData.city) return "Previsão do tempo"
            let tip = root.weatherData.city
            if (root.weatherData.temperature && root.weatherData.temperature !== "--")
                tip += " • " + root.weatherData.temperature + "°C"
            if (root.weatherData.description && root.weatherData.description !== "Previsão indisponível")
                tip += " • " + root.weatherData.description
            return tip
        }
        textColor: theme.offWhite

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.toggleDashboardRequested()
                WeatherState.requestToggleDashboard(root.Window.window)
            } else if (mouse.button === Qt.RightButton) {
                root.refreshAll()
            }
        }

        mouseArea.onWheel: function(wheel) {
            root.cycleCity(wheel.angleDelta.y < 0 ? "next" : "prev")
            wheel.accepted = true
        }
    }
}
