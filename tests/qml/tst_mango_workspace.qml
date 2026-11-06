import QtQuick
import QtTest
import "../../services/MangoWorkspace.js" as Mango

TestCase {
    name: "MangoWorkspace"

    function test_snapshotNormalizesNativeMonitorAndTagState() {
        const state = Mango.normalizeSnapshot({
            monitors: [{
                name: "eDP-1",
                active: true,
                active_tags: [2],
                tags: [
                    {index: 1, is_active: false, is_urgent: false, client_count: 1},
                    {index: 2, is_active: true, is_urgent: false, client_count: 0},
                    {index: 3, is_active: false, is_urgent: true, client_count: 0},
                    {index: 10, is_active: false, is_urgent: false, client_count: 0}
                ]
            }]
        })

        compare(state.version, 1)
        compare(state.provider, "mango-mmsg")
        compare(state.focusedOutput, "eDP-1")
        compare(state.outputs["eDP-1"].tags.length, 3)
        compare(state.outputs["eDP-1"].tags[1].active, true)
        compare(state.outputs["eDP-1"].tags[2].urgent, true)
        compare(Mango.visibleTags(state.outputs["eDP-1"]).map(tag => tag.number).join(","), "1,2,3")
    }

    function test_unknownOrMalformedSnapshotsAreIgnored() {
        compare(Mango.normalizeSnapshot(null), null)
        compare(Mango.normalizeSnapshot({}), null)
        compare(Mango.normalizeSnapshot({monitors: "invalid"}), null)
    }

    function test_currentMmsgAllTagsPayloadNormalizes() {
        const state = Mango.normalizeSnapshot({
            all_tags: [{
                monitor: "eDP-1",
                tags: [
                    {index: 1, is_active: false, is_urgent: false, client_count: 0},
                    {index: 2, is_active: true, is_urgent: false, client_count: 1},
                    {index: 3, is_active: false, is_urgent: false, client_count: 0}
                ]
            }]
        })

        verify(state !== null)
        compare(state.outputs["eDP-1"].tags.length, 3)
        compare(state.outputs["eDP-1"].tags[1].active, true)
        compare(Mango.visibleTags(state.outputs["eDP-1"]).map(tag => tag.number).join(","), "2")
    }

    function test_currentMmsgAllMonitorsPayloadTracksFocusedOutput() {
        const state = Mango.normalizeSnapshot({
            monitors: [{
                name: "HDMI-A-1",
                active: false,
                tags: [{index: 1, is_active: true, client_count: 0}]
            }, {
                name: "eDP-1",
                active: true,
                active_tags: [2],
                tags: [{index: 2, is_active: true, client_count: 1}]
            }]
        })

        verify(state !== null)
        compare(state.focusedOutput, "eDP-1")
        compare(state.outputs["eDP-1"].focused, true)
        compare(state.outputs["HDMI-A-1"].focused, false)
    }

    function test_adjacentNavigationIncludesEmptyTagsAndWraps() {
        compare(Mango.adjacentTag(4, -1, 9), 3)
        compare(Mango.adjacentTag(4, 1, 9), 5)
        compare(Mango.adjacentTag(1, -1, 9), 9)
        compare(Mango.adjacentTag(9, 1, 9), 1)
        compare(Mango.adjacentTag(0, 1, 9), null)
    }
}
