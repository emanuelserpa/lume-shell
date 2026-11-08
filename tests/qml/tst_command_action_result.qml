import QtQuick
import QtTest
import "../../components/CommandActionResult.js" as ActionResult
import "../../services/CommandProcessLifecycle.js" as ProcessLifecycle

TestCase {
    name: "CommandActionResult"

    function test_jsonSuccessRequiresZeroExit() {
        const outcome = ActionResult.complete(
            9, '{"ok":true,"version":1,"data":{"value":7}}', "", "Falha")
        verify(!outcome.ok)
        verify(!outcome.result.ok)
        verify(outcome.error.length > 0)
    }

    function test_nonzeroExitReportsStderr() {
        const outcome = ActionResult.complete(3, "", "diagnostic failure", "Falha")
        verify(!outcome.ok)
        compare(outcome.error, "diagnostic failure")
    }

    function test_emptyStdoutIsFailure() {
        const outcome = ActionResult.complete(0, "", "", "Falha")
        verify(!outcome.ok)
        verify(outcome.error.length > 0)
    }

    function test_validJsonSuccess() {
        const outcome = ActionResult.complete(
            0, '{"ok":true,"version":1,"data":{"value":7}}', "", "Falha")
        verify(outcome.ok)
        compare(outcome.result.data.value, 7)
        compare(outcome.error, "")
    }

    function test_restartIsConsumedOnlyAfterOldProcessExit() {
        const state = {restartPending: false}
        verify(ProcessLifecycle.requestRestart(state, true))
        verify(!ProcessLifecycle.requestRestart(state, false))
        verify(ProcessLifecycle.consumeRestart(state))
        verify(!state.restartPending)
        verify(!ProcessLifecycle.consumeRestart(state))
    }

    function test_restartDoesNotQueueWhenProcessIsIdle() {
        const state = {restartPending: false}
        verify(!ProcessLifecycle.requestRestart(state, false))
        verify(!ProcessLifecycle.consumeRestart(state))
    }

    function test_startFailureAppliesOnlyBeforeAStartWasObserved() {
        const state = {restartPending: false, startObserved: false}
        ProcessLifecycle.requestStart(state)
        verify(ProcessLifecycle.shouldReportStartFailure(state, false))
        ProcessLifecycle.observeStart(state)
        verify(!ProcessLifecycle.shouldReportStartFailure(state, false))
    }

    function test_pendingRestartSuppressesFailureForStoppedRun() {
        const state = {restartPending: false, startObserved: true}
        verify(ProcessLifecycle.requestRestart(state, true))
        verify(!ProcessLifecycle.shouldReportStartFailure(state, false))
        verify(ProcessLifecycle.consumeRestart(state))
        ProcessLifecycle.requestStart(state)
        verify(ProcessLifecycle.shouldReportStartFailure(state, false))
    }
}
