import QtQuick
import QtTest
import "../../services/BatteryPowerPolicy.js" as BatteryPowerPolicy

TestCase {
    name: "BatteryPowerPolicy"

    function test_activatesExtraLowPowerAtOrBelowFifteenAndRestoresOnPlug() {
        let state = { autoApplied: false, manualOverride: false, previousProfile: "balanced" }

        const above = BatteryPowerPolicy.evaluateBatteryTransition(state, 16, true, false, "balanced")
        compare(above.action, "none")
        verify(!above.autoApplied)

        const atFifteen = BatteryPowerPolicy.evaluateBatteryTransition(above, 15, true, false, "balanced")
        compare(atFifteen.action, "activate")
        compare(atFifteen.targetProfile, "extra-low-power")
        verify(atFifteen.autoApplied)
        compare(atFifteen.previousProfile, "balanced")

        // Stays active while discharging at 12% without retriggering.
        const stillLow = BatteryPowerPolicy.evaluateBatteryTransition(atFifteen, 12, true, false, "extra-low-power")
        compare(stillLow.action, "none")
        verify(stillLow.autoApplied)

        // Plugging in restores the saved previous profile.
        const plugged = BatteryPowerPolicy.evaluateBatteryTransition(stillLow, 12, false, true, "extra-low-power")
        compare(plugged.action, "restore")
        compare(plugged.targetProfile, "balanced")
        verify(!plugged.autoApplied)
    }

    function test_manualOverrideBelowThresholdIsRespectedUntilPluggedOrHysteresis() {
        let state = { autoApplied: true, manualOverride: false, previousProfile: "balanced" }

        state = BatteryPowerPolicy.noteManualSelection(state, "power-saver", 12, false)
        verify(!state.autoApplied)
        verify(state.manualOverride)

        // Still at 10% discharging: must not force extra-low-power back.
        const stayedManual = BatteryPowerPolicy.evaluateBatteryTransition(state, 10, true, false, "power-saver")
        compare(stayedManual.action, "none")
        verify(stayedManual.manualOverride)

        // Plugging in clears the manual override so future discharges can trigger again.
        const plugged = BatteryPowerPolicy.evaluateBatteryTransition(stayedManual, 10, false, true, "power-saver")
        compare(plugged.action, "none")
        verify(!plugged.manualOverride)
    }
}
