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
}
