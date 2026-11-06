import QtQuick
import QtTest
import "../../launcher/GalleryNav.js" as GalleryNav

TestCase {
    name: "GalleryNav"

    function test_clampIndex() {
        compare(GalleryNav.clampIndex(2, 5), 2)
        compare(GalleryNav.clampIndex(-3, 5), 0)
        compare(GalleryNav.clampIndex(9, 5), 4)
        compare(GalleryNav.clampIndex(0, 0), -1)
    }

    function test_findIndex() {
        const items = [{id: "a"}, {id: "b"}]
        compare(GalleryNav.findIndex(items, function(t) { return t.id === "b" }), 1)
        compare(GalleryNav.findIndex(items, function(t) { return t.id === "z" }), -1)
        compare(GalleryNav.findIndex(null, function() { return true }), -1)
    }

    function test_gridMove() {
        // 3-col grid: idx 0 + right -> 1, + down -> 3
        compare(GalleryNav.gridMove(0, 9, 3, 1, 0), 1)
        compare(GalleryNav.gridMove(0, 9, 3, 0, 1), 3)
        // edges clamp: last row + down stays, left col + left stays
        compare(GalleryNav.gridMove(8, 9, 3, 0, 1), 8)
        compare(GalleryNav.gridMove(3, 9, 3, -1, 0), 3)
        // partial last row clamps into range
        compare(GalleryNav.gridMove(4, 7, 3, 0, 1), 6)
        compare(GalleryNav.gridMove(0, 0, 3, 1, 0), -1)
    }

    function test_linearMoveWraps() {
        compare(GalleryNav.linearMove(0, 4, 1), 1)
        compare(GalleryNav.linearMove(3, 4, 1), 0)
        compare(GalleryNav.linearMove(0, 4, -1), 3)
        // out-of-range restarts at 0 then steps
        compare(GalleryNav.linearMove(-1, 4, 1), 1)
        compare(GalleryNav.linearMove(9, 4, 0), 0)
        compare(GalleryNav.linearMove(0, 0, 1), -1)
    }

    function test_syncIndex() {
        const items = [{current: false}, {current: true}]
        compare(GalleryNav.syncIndex(items, function(t) { return t.current }), 1)
        compare(GalleryNav.syncIndex([{current: false}], function(t) { return t.current }), 0)
        compare(GalleryNav.syncIndex([], function() { return true }), -1)
    }
}
