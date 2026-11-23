import QtQuick
import QtTest
import "../../services/SliderLogic.js" as SliderLogic

TestCase {
    name: "SliderLogic"

    function test_pointerMappingAlignsOneToOneUntilDragMaximum() {
        // Track spans 0..1.5 across 300px; 1.0 (100%) sits at 200px.
        fuzzyCompare(SliderLogic.valueFromPointer(0, 300, 0, 1.5, 1.0), 0.0, 0.0001)
        fuzzyCompare(SliderLogic.valueFromPointer(100, 300, 0, 1.5, 1.0), 0.5, 0.0001)
        fuzzyCompare(SliderLogic.valueFromPointer(200, 300, 0, 1.5, 1.0), 1.0, 0.0001)
        // Clicking/dragging past the 100% notch caps cleanly at 1.0.
        fuzzyCompare(SliderLogic.valueFromPointer(250, 300, 0, 1.5, 1.0), 1.0, 0.0001)
        fuzzyCompare(SliderLogic.valueFromPointer(300, 300, 0, 1.5, 1.0), 1.0, 0.0001)
    }

    function test_wheelSteppingAllowsBoostAndSnapsAtReferenceValue() {
        // Crossing 1.0 from below pauses at 1.0 before stepping into boost.
        fuzzyCompare(SliderLogic.stepValue(0.97, true, 0.05, 0, 1.5, 1.0), 1.0, 0.0001)
        // From 1.0, wheel up enters the boost range up to 1.5.
        fuzzyCompare(SliderLogic.stepValue(1.0, true, 0.05, 0, 1.5, 1.0), 1.05, 0.0001)
        fuzzyCompare(SliderLogic.stepValue(1.48, true, 0.05, 0, 1.5, 1.0), 1.5, 0.0001)
        // Crossing 1.0 from above pauses cleanly at 1.0.
        fuzzyCompare(SliderLogic.stepValue(1.03, false, 0.05, 0, 1.5, 1.0), 1.0, 0.0001)
        fuzzyCompare(SliderLogic.stepValue(1.0, false, 0.05, 0, 1.5, 1.0), 0.95, 0.0001)
    }

    function test_boostZoneDetection() {
        verify(!SliderLogic.isBoosted(0.8, 0, 1.5, 1.0))
        verify(!SliderLogic.isBoosted(1.0, 0, 1.5, 1.0))
        verify(SliderLogic.isBoosted(1.05, 0, 1.5, 1.0))
        verify(!SliderLogic.isBoosted(1.0, 0, 1.0, -1))
    }

    function test_scrollDetentRequiresExtraTicksAtReference() {
        let barrier = { barrierTicks: 0, lastTickMs: 0 }
        // Arriving at 1.0 from below stops at 1.0 without consuming boost barrier ticks yet.
        let res = SliderLogic.stepWithDetent(barrier, 0.96, true, 0.05, 0, 1.5, 1.0, 1000, 4, 750)
        fuzzyCompare(res.value, 1.0, 0.0001)
        compare(res.state.barrierTicks, 0)
        barrier = res.state

        // First 3 consecutive upward ticks at 1.0 hold at 1.0.
        for (let i = 1; i <= 3; i++) {
            res = SliderLogic.stepWithDetent(barrier, res.value, true, 0.05, 0, 1.5, 1.0, 1000 + i * 100, 4, 750)
            fuzzyCompare(res.value, 1.0, 0.0001)
            compare(res.state.barrierTicks, i)
            barrier = res.state
        }

        // 4th upward tick within the window unlocks the boost zone.
        res = SliderLogic.stepWithDetent(barrier, res.value, true, 0.05, 0, 1.5, 1.0, 1400, 4, 750)
        fuzzyCompare(res.value, 1.05, 0.0001)
        compare(res.state.barrierTicks, 0)

        // Scrolling back down snaps cleanly at 1.0 and resets barrier state.
        res = SliderLogic.stepWithDetent(res.state, 1.03, false, 0.05, 0, 1.5, 1.0, 1500, 4, 750)
        fuzzyCompare(res.value, 1.0, 0.0001)
        compare(res.state.barrierTicks, 0)
    }

    function test_scrollDetentResetsAfterWindowTimeout() {
        let barrier = { barrierTicks: 3, lastTickMs: 1000 }
        // Pausing longer than 750ms resets the upward tick counter back to 1.
        const res = SliderLogic.stepWithDetent(barrier, 1.0, true, 0.05, 0, 1.5, 1.0, 2000, 4, 750)
        fuzzyCompare(res.value, 1.0, 0.0001)
        compare(res.state.barrierTicks, 1)
    }

    function test_consumeWheelDeltaMouseAndTouchpad() {
        let accum = { angle: 0, pixel: 0 }
        // Hi-res mouse events (< 120) accumulate until reaching 120.
        let r = SliderLogic.consumeWheelDelta(accum, 60, 0)
        compare(r.steps.length, 0)
        r = SliderLogic.consumeWheelDelta(r.state, 60, 0)
        compare(r.steps.length, 1)
        verify(r.steps[0])

        // Touchpad pixelDelta emits one step per 24px.
        r = SliderLogic.consumeWheelDelta(r.state, 0, -48)
        compare(r.steps.length, 2)
        verify(!r.steps[0])
        verify(!r.steps[1])
    }
}
