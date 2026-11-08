pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import "../services/HolidayLogic.js" as HolidayLogic
import "../services/CalendarDateLogic.js" as CalendarDateLogic

Rectangle {
    id: root

    required property var theme
    property string holidayRegion: ""
    property date shownDate: new Date()
    property date currentDate: new Date()

    signal closeRequested()

    implicitWidth: 324
    implicitHeight: 406
    radius: root.theme.radiusXl

    color: "transparent"
    border.width: 0

    readonly property int currentYear: root.currentDate.getFullYear()
    readonly property bool isLeapYear: (currentYear % 4 === 0 && currentYear % 100 !== 0) || (currentYear % 400 === 0)
    readonly property int daysInCurrentYear: isLeapYear ? 366 : 365
    readonly property int dayOfYear: {
        const now = root.currentDate
        const start = new Date(now.getFullYear(), 0, 0)
        const diff = (now - start) + ((start.getTimezoneOffset() - now.getTimezoneOffset()) * 60 * 1000)
        const oneDay = 1000 * 60 * 60 * 24
        return Math.floor(diff / oneDay)
    }
    readonly property real yearProgress: Math.max(0, Math.min(1, dayOfYear / daysInCurrentYear))

    readonly property var upcomingHolidays:
        HolidayLogic.nextHolidays(root.currentDate, root.holidayRegion, 2)

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            const now = new Date()
            const refreshed = CalendarDateLogic.datesAfterRefresh(
                root.shownDate, root.currentDate, now)
            root.currentDate = refreshed.currentDate
            root.shownDate = refreshed.shownDate
        }
    }

    function monthName(m) {
        const names = [
            "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
        ]
        return names[m]
    }

    property bool startOnMonday: true
    readonly property var weekdayNames: startOnMonday
        ? ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
        : ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    readonly property bool isCurrentMonth:
        CalendarDateLogic.followsCurrentMonth(root.shownDate, root.currentDate)

    function firstWeekday() {
        const d = new Date(shownDate.getFullYear(), shownDate.getMonth(), 1)
        return startOnMonday ? (d.getDay() + 6) % 7 : d.getDay()
    }

    function daysInMonth() {
        return new Date(
            shownDate.getFullYear(),
            shownDate.getMonth() + 1,
            0
        ).getDate()
    }

    function prevMonth() {
        shownDate = new Date(
            shownDate.getFullYear(),
            shownDate.getMonth() - 1,
            1
        )
    }

    function nextMonth() {
        shownDate = new Date(
            shownDate.getFullYear(),
            shownDate.getMonth() + 1,
            1
        )
    }

    function resetDate() {
        currentDate = new Date()
        shownDate = currentDate
    }

    function formattedHeaderDate() {
        const d = root.shownDate
        const weekdays = [
            "Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira",
            "Quinta-feira", "Sexta-feira", "Sábado"
        ]
        const months = [
            "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
        ]
        return weekdays[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()]
    }

    function getISOWeek(d) {
        const date = new Date(d.getTime())
        date.setHours(0, 0, 0, 0)
        date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7)
        const week1 = new Date(date.getFullYear(), 0, 4)
        return 1 + Math.round(((date.getTime() - week1.getTime()) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.theme.popupInsets.standard
        spacing: root.theme.spacingTokens.xs

        // Header: Date by name
        Item {
            width: parent.width
            height: 18

            Item {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: headerDateRow.implicitWidth
                height: 18

                Row {
                    id: headerDateRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.theme.spacingTokens.sm

                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.dashboardBodyFontSize
                        height: width
                        iconName: "bar-calendar"
                        iconColor: root.theme.accent
                    }

                    Text {
                        renderType: Text.NativeRendering
                        text: root.formattedHeaderDate()
                        color: headerDateMouse.containsMouse && !root.isCurrentMonth
                               ? root.theme.accent
                               : root.theme.offWhite
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardMetaFontSize
                        font.weight: Font.Medium
                        opacity: 0.85
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: headerDateMouse
                    anchors.fill: parent
                    enabled: !root.isCurrentMonth
                    hoverEnabled: enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetDate()
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: todayBtnRow.implicitWidth + 8
                radius: root.theme.radiusXs
                visible: !root.isCurrentMonth
                color: todayBtnMouse.containsMouse
                       ? root.theme.accentMuted
                       : root.theme.glassHoverSurface

                Row {
                    id: todayBtnRow
                    anchors.centerIn: parent
                    spacing: root.theme.spacingTokens.tight

                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.dashboardMetaFontSize
                        height: width
                        iconName: "dashboard-today"
                        iconColor: root.theme.accent
                    }

                    Text {
                        renderType: Text.NativeRendering
                        text: "Hoje"
                        color: root.theme.offWhite
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardMetaFontSize
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: todayBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetDate()
                }
            }
        }

        // Month Navigation
        Row {
            width: parent.width
            height: 22

            Item {
                width: 26
                height: parent.height

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.dashboardBodyFontSize
                    height: width
                    iconName: "dashboard-chevron-left"
                    iconColor: prevMonthHover.hovered ? root.theme.foreground : root.theme.surfaceVariantForeground
                }

                HoverHandler { id: prevMonthHover }
                TapHandler { onTapped: root.prevMonth() }
            }

            Text {
                renderType: Text.NativeRendering
                width: parent.width - 52
                height: parent.height
                text: root.monthName(root.shownDate.getMonth()) + " " + root.shownDate.getFullYear()
                color: monthClickHover.hovered && !root.isCurrentMonth
                       ? root.theme.accent
                       : root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.dashboardHeadingFontSize
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                HoverHandler { id: monthClickHover }
                TapHandler {
                    onTapped: {
                        if (!root.isCurrentMonth) root.resetDate()
                    }
                }
            }

            Item {
                width: 26
                height: parent.height

                TablerIcon {
                    anchors.centerIn: parent
                    width: root.theme.dashboardBodyFontSize
                    height: width
                    iconName: "dashboard-chevron-right"
                    iconColor: nextMonthHover.hovered ? root.theme.foreground : root.theme.surfaceVariantForeground
                }

                HoverHandler { id: nextMonthHover }
                TapHandler { onTapped: root.nextMonth() }
            }
        }

        // Weekday names
        Row {
            width: parent.width
            height: 15
            spacing: 0

            Rectangle {
                width: 24
                height: parent.height
                radius: root.theme.radiusXs
                color: semHover.containsMouse
                       ? root.theme.glassHoverSurface
                       : "transparent"

                Text {
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    text: "Sem"
                    color: semHover.containsMouse ? root.theme.accent : root.theme.grey
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardLabelFontSize
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: semHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startOnMonday = !root.startOnMonday
                }
            }

            Rectangle {
                width: 1
                height: 11
                anchors.verticalCenter: parent.verticalCenter
                color: root.theme.glassBorderSubtle
            }

            Item { width: 5; height: 1 }

            Row {
                width: parent.width - 30
                height: parent.height

                Repeater {
                    model: root.weekdayNames

                    delegate: Text {
                        renderType: Text.NativeRendering
                        required property string modelData
                        width: parent.width / 7
                        height: parent.height
                        text: modelData
                        color: root.theme.grey
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardLabelFontSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Calendar Grid by Weeks
        Column {
            id: calendarGrid
            width: parent.width
            spacing: root.theme.spacingTokens.micro

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    if (event.angleDelta.y < 0) {
                        root.nextMonth()
                    } else if (event.angleDelta.y > 0) {
                        root.prevMonth()
                    }
                }
            }

            Repeater {
                model: 6

                delegate: Row {
                    id: weekRow
                    required property int index

                    readonly property int rowIndex: index

                    // Check if this row has any days in the shown month
                    readonly property int rowStartDay: 1 - root.firstWeekday() + (rowIndex * 7)
                    readonly property int rowEndDay: rowStartDay + 6
                    readonly property bool rowHasDays: rowStartDay <= root.daysInMonth() && rowEndDay >= 1

                    // Date of the Monday of this week
                    readonly property date rowDate: new Date(root.shownDate.getFullYear(), root.shownDate.getMonth(), rowStartDay)
                    readonly property int weekNumber: root.getISOWeek(rowDate)

                    width: parent ? parent.width : 0
                    height: 25
                    spacing: 0

                    // Week number
                    Text {
                        renderType: Text.NativeRendering
                        width: 24
                        height: parent.height
                        text: weekRow.rowHasDays ? weekRow.weekNumber : ""
                        color: root.theme.grey
                        opacity: 0.65
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.dashboardMetaFontSize
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Keep the week-number column clear for single- and double-digit weeks.
                    Item { width: 6; height: 1 }

                    // 7 days of the week
                    Row {
                        width: parent.width - 30
                        height: parent.height
                        spacing: root.theme.spacingTokens.tiny

                        Repeater {
                            model: 7

                            delegate: Rectangle {
                                id: dayCell
                                required property int index

                                readonly property int day: weekRow.rowStartDay + index
                                readonly property bool valid: day >= 1 && day <= root.daysInMonth()

                                readonly property date today: root.currentDate
                                readonly property bool isToday:
                                    valid
                                    && day === today.getDate()
                                    && root.shownDate.getMonth() === today.getMonth()
                                    && root.shownDate.getFullYear() === today.getFullYear()

                                width: (parent.width - 12) / 7
                                height: 25
                                radius: root.theme.radiusSm

                                color: isToday
                                       ? root.theme.accent
                                       : (dayHover.hovered && valid ? root.theme.glassHoverSurface : "transparent")

                                Text {
                                    renderType: Text.NativeRendering
                                    anchors.centerIn: parent
                                    text: dayCell.valid ? dayCell.day : ""
                                    color: dayCell.isToday
                                           ? root.theme.primaryForeground
                                           : root.theme.offWhite
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.dashboardBodyFontSize
                                    font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                                }

                                HoverHandler { id: dayHover; enabled: dayCell.valid }
                            }
                        }
                    }
                }
            }
        }

        // Year Progress Strip (Strictly bounded)
        Column {
            width: parent.width
            spacing: root.theme.spacingTokens.tight

            Item {
                width: parent.width
                height: 14

                Text {
                    renderType: Text.NativeRendering
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ano " + root.currentYear
                    color: root.theme.grey
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardMetaFontSize
                }

                Text {
                    renderType: Text.NativeRendering
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.yearProgress * 100) + "%  •  dia " + root.dayOfYear + " de " + root.daysInCurrentYear
                    color: root.theme.offWhite
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardMetaFontSize
                }
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: root.theme.radiusXs
                color: root.theme.sliderTrack
                clip: true

                Rectangle {
                    width: Math.min(parent.width, Math.max(0, parent.width * root.yearProgress))
                    height: parent.height
                    radius: root.theme.radiusXs
                    color: root.theme.accent
                }
            }
        }

        // Separate the calendar from the upcoming holiday pills.
        Item {
            width: parent.width
            height: 6

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 1
                color: root.theme.glassBorderSubtle
            }
        }

        // Two upcoming holidays keep the calendar useful beyond the current month.
        Item {
            width: parent.width
            height: 124

            Column {
                anchors.fill: parent
                spacing: root.theme.spacingTokens.xs

                Text {
                    renderType: Text.NativeRendering
                    width: parent.width
                    height: 18
                    text: "Próximos feriados"
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardHeadingFontSize
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    width: parent.width
                    model: root.upcomingHolidays

                    delegate: HolidayPill {
                        required property var modelData
                        required property int index
                        width: parent.width
                        theme: root.theme
                        holiday: modelData
                        highlighted: index === 0
                    }
                }

            }
        }

    }
}
