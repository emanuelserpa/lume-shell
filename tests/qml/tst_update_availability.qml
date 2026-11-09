import QtQuick
import QtTest
import "../../services/UpdateAvailability.js" as UpdateAvailability

TestCase {
    name: "UpdateAvailability"

    function test_showsIndicatorWhenUpdatesAreAvailable() {
        verify(UpdateAvailability.shouldShowIndicator(3, false, ""))
    }

    function test_showsIndicatorWhileUpdatingWithoutKnownCounts() {
        verify(UpdateAvailability.shouldShowIndicator(0, true, ""))
    }

    function test_keepsIndicatorForRestoredResultWhenCountIsZero() {
        verify(UpdateAvailability.shouldShowIndicator(0, false, "Atualização concluída."))
        verify(UpdateAvailability.shouldShowIndicator(0, false, "Falha ao atualizar."))
    }

    function test_hidesIndicatorWithoutUpdatesOrResult() {
        verify(!UpdateAvailability.shouldShowIndicator(0, false, ""))
        verify(!UpdateAvailability.shouldShowIndicator(-1, false, "  "))
    }
}
