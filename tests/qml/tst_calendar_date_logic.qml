import QtQuick
import QtTest
import "../../services/CalendarDateLogic.js" as CalendarDateLogic

TestCase {
    name: "CalendarDateLogic"

    function test_followsCurrentMonthAcrossDays() {
        verify(CalendarDateLogic.followsCurrentMonth(
            new Date(2026, 11, 1), new Date(2026, 11, 31)))
        verify(CalendarDateLogic.followsCurrentMonth(
            new Date(2026, 11, 1), new Date(2027, 0, 1)) === false)
    }

    function test_keepsIntentionallyBrowsedMonth() {
        verify(!CalendarDateLogic.followsCurrentMonth(
            new Date(2026, 9, 1), new Date(2026, 10, 30)))
        verify(!CalendarDateLogic.followsCurrentMonth(
            new Date(2025, 10, 1), new Date(2026, 10, 30)))
    }

    function test_tracksCurrentMonthAtMonthBoundary() {
        verify(CalendarDateLogic.followsCurrentMonth(
            new Date(2026, 10, 1), new Date(2026, 10, 30)))
        verify(!CalendarDateLogic.followsCurrentMonth(
            new Date(2026, 10, 1), new Date(2026, 11, 1)))
    }

    function test_refreshFollowsTodayAcrossMonthAndYearBoundaries() {
        const march = new Date(2026, 2, 31, 23, 59)
        const april = new Date(2026, 3, 1, 0, 1)
        let refreshed = CalendarDateLogic.datesAfterRefresh(march, march, april)
        compare(refreshed.currentDate.getTime(), april.getTime())
        compare(refreshed.shownDate.getTime(), april.getTime())

        const december = new Date(2026, 11, 31, 23, 59)
        const january = new Date(2027, 0, 1, 0, 1)
        refreshed = CalendarDateLogic.datesAfterRefresh(december, december, january)
        compare(refreshed.currentDate.getTime(), january.getTime())
        compare(refreshed.shownDate.getTime(), january.getTime())
    }

    function test_refreshPreservesIntentionallyBrowsedMonthAtBoundary() {
        const current = new Date(2026, 2, 31, 23, 59)
        const browsed = new Date(2026, 0, 1)
        const now = new Date(2026, 3, 1, 0, 1)
        const refreshed = CalendarDateLogic.datesAfterRefresh(browsed, current, now)
        compare(refreshed.currentDate.getTime(), now.getTime())
        compare(refreshed.shownDate.getTime(), browsed.getTime())
    }
}
