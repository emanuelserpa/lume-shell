import QtQuick
import QtTest
import "../../services/ProcessLifecycle.js" as ProcessLifecycle

TestCase {
    name: "ProcessLifecycle"

    function test_stopIsConsumedOnlyAfterObservedStart() {
        const process = {running: false, observedStart: false}

        verify(!ProcessLifecycle.consumeStartedStop(process))
        compare(process.observedStart, false)

        process.running = true
        verify(!ProcessLifecycle.consumeStartedStop(process))
        compare(process.observedStart, true)

        process.running = false
        verify(ProcessLifecycle.consumeStartedStop(process))
        compare(process.observedStart, false)
        verify(!ProcessLifecycle.consumeStartedStop(process))
    }
}
