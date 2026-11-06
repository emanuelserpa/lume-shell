pragma Singleton
import QtQuick
import Quickshell
import qs.components

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property var weatherData: weather.result.data
    readonly property var citiesData: cities.result.data
    readonly property bool hasWeatherText: weather.text.length > 0
    property var activeWindow: null

    signal cityChanged()
    signal toggleDashboardRequested(var targetWindow)

    function requestToggleDashboard(targetWindow) {
        root.toggleDashboardRequested(targetWindow)
    }

    function setDashboardOpen(targetWindow, isOpen) {
        if (isOpen) {
            root.activeWindow = targetWindow
        } else if (root.activeWindow === targetWindow) {
            root.activeWindow = null
        }
    }

    function refreshAll() {
        cities.refresh()
        weather.refresh()
    }

    function handleCityProcessFinished() {
        cities.refresh()
        weather.refresh()
        root.cityChanged()
    }

    function selectCity(id) {
        citySelectProc.run(["select", id])
    }

    function removeCity(id) {
        cityRemoveProc.run(["remove", id])
    }

    function addCity(id, name, region, country, latitude, longitude) {
        cityAddProc.run([
            "add",
            "--id", id,
            "--name", name,
            "--region", region,
            "--country", country,
            "--latitude", String(latitude),
            "--longitude", String(longitude)
        ])
    }

    function cycleCity(direction) {
        cycleProc.run(["cycle", direction])
    }

    CommandJson {
        id: weather
        command: ["python3", Quickshell.shellDir + "/scripts/weather-fetch.py"]
        interval: 300000
    }

    CommandJson {
        id: cities
        command: ["python3", Quickshell.shellDir + "/scripts/weather-cities.py", "list"]
        interval: 0
    }

    CommandAction {
        id: cycleProc
        baseCommand: ["python3", Quickshell.shellDir + "/scripts/weather-cities.py"]
        onFinished: root.handleCityProcessFinished()
    }

    CommandAction {
        id: citySelectProc
        baseCommand: ["python3", Quickshell.shellDir + "/scripts/weather-cities.py"]
        onFinished: root.handleCityProcessFinished()
    }

    CommandAction {
        id: cityRemoveProc
        baseCommand: ["python3", Quickshell.shellDir + "/scripts/weather-cities.py"]
        onFinished: root.handleCityProcessFinished()
    }

    CommandAction {
        id: cityAddProc
        baseCommand: ["python3", Quickshell.shellDir + "/scripts/weather-cities.py"]
        onFinished: root.handleCityProcessFinished()
    }
}
