import QtQuick
import QtTest
import "../../services/UpdateAvailability.js" as UpdateAvailability

TestCase {
    name: "UpdateAvailability"

    function test_showsIndicatorWhenUpdatesAreAvailable() {
        verify(UpdateAvailability.shouldShowIndicator(3, false))
    }

    function test_showsIndicatorWhileUpdatingWithoutKnownCounts() {
        verify(UpdateAvailability.shouldShowIndicator(0, true))
    }

    function test_hidesIndicatorAfterCompletionWhenNoUpdatesRemain() {
        verify(!UpdateAvailability.shouldShowIndicator(0, false))
    }

    function test_hidesIndicatorWithoutUpdatesOrWhileIdle() {
        verify(!UpdateAvailability.shouldShowIndicator(0, false))
        verify(!UpdateAvailability.shouldShowIndicator(-1, false))
    }
}
