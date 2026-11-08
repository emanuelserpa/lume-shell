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
}
