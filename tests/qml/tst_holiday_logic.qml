import QtQuick
import QtTest
import "../../services/HolidayLogic.js" as HolidayLogic

TestCase {
    name: "HolidayLogic"

    function test_nextNationalHoliday() {
        const holidays = HolidayLogic.nextHolidays(new Date(2026, 9, 5), "", 2)
        compare(holidays.length, 2)
        compare(holidays[0].name, "Nossa Senhora Aparecida")
        compare(holidays[0].dateLabel, "12 out")
        compare(holidays[0].daysUntil, 7)
        compare(holidays[1].name, "Finados")
    }

    function test_includesCearaHoliday() {
        const holidays = HolidayLogic.nextHolidays(new Date(2026, 2, 20), "Ceará", 1)
        compare(holidays[0].name, "Data Magna do Ceará")
        compare(holidays[0].daysUntil, 5)
    }

    function test_calculatesGoodFriday() {
        const holidays = HolidayLogic.nextHolidays(new Date(2026, 3, 1), "", 1)
        compare(holidays[0].name, "Paixão de Cristo")
        compare(holidays[0].date.getDate(), 3)
        compare(holidays[0].date.getMonth(), 3)
    }

    function test_includesHolidayToday() {
        const holidays = HolidayLogic.nextHolidays(new Date(2026, 10, 20), "", 1)
        compare(holidays[0].name, "Consciência Negra")
        compare(holidays[0].countdown, "Hoje")
    }
}
