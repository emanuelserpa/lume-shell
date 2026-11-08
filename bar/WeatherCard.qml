pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "../services/CommandResult.js" as CommandResult

Rectangle {
    id: root

    required property var theme
    property var weatherData: ({})
    property var citiesData: ({})
    property bool cityMenuOpen: false
    property bool addMode: false
    property var searchResults: []
    property string searchError: ""
    property string citySearchText: ""

    signal refreshRequested()
    signal citySelected(string id)
    signal cityRemoved(string id)
    signal cityAdded(string id, string name, string region, string country,
                     real latitude, real longitude)

    implicitWidth: 334
    implicitHeight: 406
    radius: root.theme.radiusXl

    color: "transparent"
    border.width: 0

    function value(name, fallback) {
        const v = weatherData ? weatherData[name] : undefined
        return (v === undefined || v === null || String(v).length === 0)
               ? fallback : String(v)
    }

    function weatherIconName(glyph) {
        const icons = {
            "󰖙": "bar-sun", "󰖕": "bar-cloud-sun", "󰖐": "bar-cloud",
            "󰖗": "bar-rain", "󰖖": "bar-rain", "󰙾": "bar-storm",
            "󰖘": "bar-snow", "󰖑": "bar-fog"
        }
        return icons[String(glyph ?? "")] ?? "bar-cloud"
    }

    function doSearch() {
        const q = root.citySearchText.trim()
        if (q.length < 2) {
            root.searchResults = []
            root.searchError = ""
            return
        }

        root.searchError = ""
        searchProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/weather-cities.py",
            "search",
            q
        ]

        if (!searchProc.running)
            searchProc.running = true
    }

    Process {
        id: searchProc

        stdout: StdioCollector {
            onStreamFinished: {
                const response = CommandResult.decode(this.text)
                root.searchResults = response.ok ? (response.data.results ?? []) : []
                root.searchError = response.ok ? "" : response.error
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.theme.popupInsets.standard
        spacing: root.theme.spacingTokens.sm

        // Top city selector + quick add button
        Row {
            width: parent.width
            height: 34
            spacing: root.theme.spacingTokens.sm

            Rectangle {
                width: parent.width - 40
                height: 34
                radius: root.theme.radiusSm
                color: cityHeaderHover.hovered || root.cityMenuOpen
                       ? root.theme.glassHoverSurface
                       : root.theme.glassCardSurface

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.theme.spacingTokens.md
                    anchors.rightMargin: root.theme.spacingTokens.md
                    spacing: root.theme.spacingTokens.smPlus

                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.dashboardBodyFontSize
                        height: width
                        iconName: "dashboard-location"
                        iconColor: root.theme.accent
                    }

                    Text {
                        renderType: Text.NativeRendering
                        width: parent.width - 44
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.value("city", "Localização automática")
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardTitleFontSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.dashboardLabelFontSize
                        height: width
                        iconName: root.cityMenuOpen ? "dashboard-chevron-left" : "dashboard-chevron-right"
                        iconColor: root.theme.surfaceVariantForeground
                    }
                }

                HoverHandler { id: cityHeaderHover }

                TapHandler {
                    onTapped: {
                        root.cityMenuOpen = !root.cityMenuOpen
                        root.addMode = false
                        root.searchResults = []
                    }
                }
            }

            Rectangle {
                width: 34
                height: 34
                radius: root.theme.radiusXl
                color: addTopHover.hovered
                       ? root.theme.glassHoverSurface
                       : root.theme.glassCardSurface

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.dashboardBodyFontSize
                    height: width
                    iconName: "dashboard-plus"
                    iconColor: root.theme.accent
                }

                HoverHandler { id: addTopHover }

                TapHandler {
                    onTapped: {
                        root.cityMenuOpen = true
                        root.addMode = true
                        root.searchResults = []
                        citySearch.forceActiveFocus()
                    }
                }
            }
        }

        // City management mode
        Item {
            visible: root.cityMenuOpen
            width: parent.width
            height: visible ? 336 : 0

            Column {
                anchors.fill: parent
                spacing: root.theme.spacingTokens.smPlus

                Text {
                    renderType: Text.NativeRendering
                    text: root.addMode ? "Adicionar cidade" : "Cidades salvas"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardTitleFontSize
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: root.addMode
                    width: parent.width
                    height: visible ? 32 : 0
                    radius: root.theme.radiusSm
                    color: root.theme.glassCardSurface
                    border.width: citySearch.activeFocus ? 1 : 0
                    border.color: root.theme.accent

                    SearchField {
                        id: citySearch
                        theme: root.theme
                        anchors.fill: parent
                        anchors.leftMargin: root.theme.spacingTokens.md
                        anchors.rightMargin: 32
                        placeholderText: "Buscar cidade..."
                        placeholderColor: root.theme.grey
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.theme.foreground
                        selectionColor: root.theme.accent
                        selectedTextColor: root.theme.background
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardBodyFontSize
                        clip: true
                        onTextChanged: root.citySearchText = text

                        onAccepted: root.doSearch()
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: root.theme.spacingTokens.md
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.dashboardLabelFontSize
                        height: width

                        TablerIcon {
                            anchors.fill: parent
                            iconName: "dashboard-search"
                            iconColor: searchHover.hovered ? root.theme.foreground : root.theme.accent
                        }

                        HoverHandler { id: searchHover }
                        TapHandler { onTapped: root.doSearch() }
                    }
                }

                Item {
                    visible: root.addMode
                    width: parent.width
                    height: visible ? 260 : 0
                    ListView {
                        id: citySearchList
                        anchors.fill: parent
                        visible: root.searchResults.length > 0
                        clip: true
                        spacing: root.theme.spacingTokens.tight
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.searchResults

                        WheelKinetic { scrollTarget: citySearchList }

                        delegate: PopupListRow {
                        id: citySearchDelegate
                        theme: root.theme
                        required property var modelData
                        rowHeight: 42
                        cornerRadius: root.theme.radiusSm
                        idleColor: "transparent"
                        idleBorderWidth: 0
                        title: citySearchDelegate.modelData.name ?? ""
                        titlePixelSize: root.theme.dashboardBodyFontSize
                        subtitle: [citySearchDelegate.modelData.region, citySearchDelegate.modelData.country]
                            .filter(Boolean).join(", ")
                        subtitlePixelSize: root.theme.dashboardMetaFontSize

                        interactionHandlers: TapHandler {
                            onTapped: {
                                root.cityAdded(
                                    String(citySearchDelegate.modelData.id ?? ""),
                                    String(citySearchDelegate.modelData.name ?? ""),
                                    String(citySearchDelegate.modelData.region ?? ""),
                                    String(citySearchDelegate.modelData.country ?? ""),
                                    Number(citySearchDelegate.modelData.latitude ?? 0),
                                    Number(citySearchDelegate.modelData.longitude ?? 0)
                                )
                                root.addMode = false
                                root.cityMenuOpen = false
                            }
                        }
                        }
                    }

                    EmptyState {
                        anchors.fill: parent
                        visible: root.citySearchText.trim().length >= 2
                                 && !searchProc.running
                                 && root.searchResults.length === 0
                        theme: root.theme
                        title: root.searchError.length > 0
                               ? root.searchError
                               : "Nenhuma cidade encontrada"
                        titleSize: root.theme.dashboardBodyFontSize
                        titleColor: root.searchError.length > 0 ? root.theme.red : root.theme.grey
                    }
                }

                ListView {
                    id: savedCities
                    visible: !root.addMode
                    width: parent.width
                    height: visible ? 264 : 0
                    clip: true
                    spacing: root.theme.spacingTokens.tight
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.citiesData?.cities ?? []

                    WheelKinetic { scrollTarget: savedCities }

                    delegate: PopupListRow {
                        id: savedCityDelegate
                        theme: root.theme
                        required property var modelData
                        rowHeight: 42
                        cornerRadius: root.theme.radiusSm
                        idleColor: "transparent"
                        idleBorderWidth: 0
                        leadingTablerIcon: savedCityDelegate.modelData.selected ? "dashboard-check" : ""
                        leadingIconColor: root.theme.green
                        leadingIconPixelSize: root.theme.dashboardLabelFontSize
                        title: savedCityDelegate.modelData.name ?? ""
                        titlePixelSize: root.theme.dashboardBodyFontSize
                        titleWeight: savedCityDelegate.modelData.selected ? Font.Bold : Font.Normal
                        subtitle: savedCityDelegate.modelData.subtitle ?? ""
                        subtitlePixelSize: root.theme.dashboardMetaFontSize
                        trailing: Item {
                            visible: !savedCityDelegate.modelData.automatic
                            width: root.theme.iconTokens.lg
                            height: width

                            TablerIcon {
                                anchors.centerIn: parent
                                width: root.theme.dashboardLabelFontSize
                                height: width
                                iconName: "dashboard-trash"
                                iconColor: removeHover.hovered ? root.theme.red : root.theme.surfaceVariantForeground
                            }

                            HoverHandler { id: removeHover }
                            TapHandler {
                                onTapped: root.cityRemoved(savedCityDelegate.modelData.id)
                            }
                        }


                        interactionHandlers: TapHandler {
                            onTapped: {
                                root.citySelected(savedCityDelegate.modelData.id)
                                root.cityMenuOpen = false
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: root.theme.radiusSm
                    color: manageBackHover.hovered
                           ? root.theme.glassHoverSurface
                           : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: root.theme.spacingTokens.xsPlus

                        TablerIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.theme.dashboardLabelFontSize
                            height: width
                            iconName: "dashboard-arrow-left"
                            iconColor: root.theme.surfaceVariantForeground
                        }

                        Text {
                            renderType: Text.NativeRendering
                            text: root.addMode ? "Voltar para cidades" : "Voltar para previsão"
                            color: root.theme.grey
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.dashboardLabelFontSize
                        }
                    }

                    HoverHandler { id: manageBackHover }

                    TapHandler {
                        onTapped: {
                            if (root.addMode) {
                                root.addMode = false
                                root.searchResults = []
                            } else {
                                root.cityMenuOpen = false
                            }
                        }
                    }
                }
            }
        }

        // Main weather view
        Item {
            visible: !root.cityMenuOpen
            width: parent.width
            height: visible ? 336 : 0

            Column {
                anchors.fill: parent
                spacing: root.theme.spacingTokens.smPlus

                // Current Condition
                Row {
                    width: parent.width
                    height: 72
                    spacing: root.theme.spacingTokens.smPlus

                    TablerIcon {
                        width: 54
                        height: 54
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: root.weatherIconName(root.value("icon", "󰖐"))
                        iconColor: root.theme.yellow
                    }

                    Column {
                        width: parent.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.theme.spacingTokens.micro

                        Text {
                            renderType: Text.NativeRendering
                            text: root.value("temperature", "--") + "°C"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.dashboardHeroFontSize
                            font.weight: Font.Bold
                        }

                        Text {
                            renderType: Text.NativeRendering
                            width: parent.width
                            text: root.value("description", "Previsão indisponível")
                            color: root.theme.offWhite
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.dashboardBodyFontSize
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        width: 52
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.theme.spacingTokens.sm

                        Row {
                            spacing: root.theme.spacingTokens.xs
                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.dashboardLabelFontSize
                                height: width
                                iconName: "dashboard-arrow-up"
                                iconColor: root.theme.surfaceVariantForeground
                            }
                            Text {
                                renderType: Text.NativeRendering
                                text: ((root.weatherData?.days ?? []).length > 0
                                       ? root.weatherData.days[0].maxtemp : "--") + "°"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardBodyFontSize
                            }
                        }

                        Row {
                            spacing: root.theme.spacingTokens.xs
                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.dashboardLabelFontSize
                                height: width
                                iconName: "dashboard-arrow-down"
                                iconColor: root.theme.blue
                            }
                            Text {
                                renderType: Text.NativeRendering
                                text: ((root.weatherData?.days ?? []).length > 0
                                       ? root.weatherData.days[0].mintemp : "--") + "°"
                                color: root.theme.offWhite
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardBodyFontSize
                            }
                        }
                    }
                }

                // Next six hours
                Row {
                    width: parent.width
                    height: 56
                    spacing: root.theme.spacingTokens.tiny

                    Repeater {
                        model: root.weatherData?.hours ?? []

                        delegate: Column {
                            id: hourlyForecastDelegate
                            required property var modelData

                            width: (parent.width - 10) / 6
                            spacing: root.theme.spacingTokens.tiny

                            Text {
                                renderType: Text.NativeRendering
                                width: parent.width
                                text: hourlyForecastDelegate.modelData.label ?? ""
                                color: root.theme.grey
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardMetaFontSize
                                horizontalAlignment: Text.AlignHCenter
                            }

                            TablerIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: root.theme.dashboardMetricFontSize
                                height: width
                                iconName: root.weatherIconName(hourlyForecastDelegate.modelData.icon)
                                iconColor: root.theme.yellow
                            }

                            Text {
                                renderType: Text.NativeRendering
                                width: parent.width
                                text: (hourlyForecastDelegate.modelData.temp ?? "--") + "°"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardMetaFontSize
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Weather Metrics Row
                Row {
                    width: parent.width
                    height: 26
                    spacing: root.theme.spacingTokens.sm

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: root.theme.radiusSm
                        color: root.theme.glassCardSurface

                        Row {
                            anchors.centerIn: parent
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.dashboardBodyFontSize
                                height: width
                                iconName: "dashboard-thermometer"
                                iconColor: root.theme.orange
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: (root.weatherData?.feels_like ?? "--") + "°C"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardMetaFontSize
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: root.theme.radiusSm
                        color: root.theme.glassCardSurface

                        Row {
                            anchors.centerIn: parent
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.dashboardBodyFontSize
                                height: width
                                iconName: "dashboard-humidity"
                                iconColor: root.theme.cyan
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: (root.weatherData?.humidity ?? "--") + "%"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardMetaFontSize
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: root.theme.radiusSm
                        color: root.theme.glassCardSurface

                        Row {
                            anchors.centerIn: parent
                            spacing: root.theme.spacingTokens.xs

                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.dashboardBodyFontSize
                                height: width
                                iconName: "dashboard-wind"
                                iconColor: root.theme.blue
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: (root.weatherData?.wind ?? "--") + " km/h"
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardMetaFontSize
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.theme.glassBorderSubtle
                }

                // Five day list
                Column {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.weatherData?.days ?? []

                        delegate: Row {
                            id: dailyForecastDelegate
                            required property var modelData

                            width: parent.width
                            height: 29

                            Text {
                                renderType: Text.NativeRendering
                                width: 110
                                anchors.verticalCenter: parent.verticalCenter
                                text: dailyForecastDelegate.modelData.label ?? ""
                                color: root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.dashboardBodyFontSize
                                elide: Text.ElideRight
                            }

                            TablerIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.theme.typeTokens.titleMedium
                                height: width
                                iconName: root.weatherIconName(
                                    (dailyForecastDelegate.modelData.periods?.length ?? 0) > 1
                                        ? dailyForecastDelegate.modelData.periods[1].icon : "󰖐"
                                )
                                iconColor: root.theme.yellow
                            }

                            Item { width: Math.max(0, parent.width - 236); height: 1 }

                            Row {
                                width: 42
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacingTokens.micro
                                layoutDirection: Qt.RightToLeft
                                TablerIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.theme.dashboardLabelFontSize
                                    height: width
                                    iconName: "dashboard-arrow-up"
                                    iconColor: root.theme.foreground
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (dailyForecastDelegate.modelData.maxtemp ?? "--") + "°"
                                    color: root.theme.foreground
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.dashboardMetaFontSize
                                    font.weight: Font.Medium
                                }
                            }

                            Row {
                                width: 42
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.theme.spacingTokens.micro
                                layoutDirection: Qt.RightToLeft
                                TablerIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.theme.dashboardLabelFontSize
                                    height: width
                                    iconName: "dashboard-arrow-down"
                                    iconColor: root.theme.blue
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (dailyForecastDelegate.modelData.mintemp ?? "--") + "°"
                                    color: root.theme.blue
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.dashboardMetaFontSize
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 14
                    spacing: root.theme.spacingTokens.xs

                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.typeTokens.meta
                        height: width
                        iconName: "dashboard-refresh"
                        iconColor: root.theme.surfaceVariantForeground
                    }

                    Text {
                        id: weatherRefreshStatus
                        renderType: Text.NativeRendering
                        width: root.weatherData?.error
                               ? Math.max(0, parent.width - 150)
                               : implicitWidth
                        text: root.weatherData?.error
                              ? "Falha: " + root.weatherData.error
                              : (root.weatherData?.updated_at
                                 ? "Atualizado às " + Qt.formatDateTime(new Date(root.weatherData.updated_at), "HH:mm")
                                 : "Previsão Open-Meteo")
                        color: root.weatherData?.error
                               ? root.theme.red
                               : root.theme.grey
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardMetaFontSize
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter

                        HoverHandler { id: weatherRefreshStatusHover }
                        ToolTipBubble {
                            theme: root.theme
                            target: weatherRefreshStatus
                            text: String(root.weatherData?.error ?? "")
                            requestedVisible: weatherRefreshStatusHover.hovered
                        }
                    }

                    Item {
                        width: root.weatherData?.error ? 0 : Math.max(0, parent.width - 200)
                        height: 1
                    }

                    Text {
                        renderType: Text.NativeRendering
                        visible: Boolean(root.weatherData?.stale)
                        text: "Última previsão válida"
                        color: root.theme.yellow
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardMetaFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
