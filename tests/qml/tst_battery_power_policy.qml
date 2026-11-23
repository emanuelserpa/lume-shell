import QtQuick
import QtTest
import "../../services/BatteryPowerPolicy.js" as BatteryPowerPolicy

TestCase {
    name: "BatteryPowerPolicy"

    function test_activatesExtraLowPowerAtOrBelowFifteenAndSwitchesToBalancedOnPlug() {
        let state = { autoApplied: false, manualOverride: false, wasPlugged: false, previousProfile: "power-saver" }

        const above = BatteryPowerPolicy.evaluateBatteryTransition(state, 16, true, false, "power-saver")
        compare(above.action, "none")
        verify(!above.autoApplied)

        const atFifteen = BatteryPowerPolicy.evaluateBatteryTransition(above, 15, true, false, "power-saver")
        compare(atFifteen.action, "activate")
        compare(atFifteen.targetProfile, "extra-low-power")
        verify(atFifteen.autoApplied)
        compare(atFifteen.previousProfile, "power-saver")

        // Stays active while discharging at 12% without retriggering.
        const stillLow = BatteryPowerPolicy.evaluateBatteryTransition(atFifteen, 12, true, false, "extra-low-power")
        compare(stillLow.action, "none")
        verify(stillLow.autoApplied)

        // Plugging in switches cleanly to balanced and lifts Ultra Eco.
        const plugged = BatteryPowerPolicy.evaluateBatteryTransition(stillLow, 12, false, true, "extra-low-power")
        compare(plugged.action, "restore")
        compare(plugged.targetProfile, "balanced")
        verify(!plugged.autoApplied)
        verify(plugged.wasPlugged)
    }

    function test_manualUltraEcoStaysIfAlreadyPluggedAndClearsWhenPluggedFromBattery() {
        // Already plugged in: manual Ultra Eco stays active.
        let pluggedState = { autoApplied: false, manualOverride: false, wasPlugged: true, previousProfile: "balanced" }
        pluggedState = BatteryPowerPolicy.noteManualSelection(pluggedState, "extra-low-power", 50, true)
        const staysOnAc = BatteryPowerPolicy.evaluateBatteryTransition(pluggedState, 50, false, true, "extra-low-power")
        compare(staysOnAc.action, "none")

        // Selected on battery, then charger plugged in: transitions to balanced.
        let batState = { autoApplied: false, manualOverride: false, wasPlugged: false, previousProfile: "power-saver" }
        batState = BatteryPowerPolicy.noteManualSelection(batState, "extra-low-power", 40, false)
        const pluggedFromBat = BatteryPowerPolicy.evaluateBatteryTransition(batState, 40, false, true, "extra-low-power")
        compare(pluggedFromBat.action, "restore")
        compare(pluggedFromBat.targetProfile, "balanced")
    }

    function test_manualOverrideBelowThresholdIsRespectedUntilPluggedOrHysteresis() {
        let state = { autoApplied: true, manualOverride: false, wasPlugged: false, previousProfile: "balanced" }

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
