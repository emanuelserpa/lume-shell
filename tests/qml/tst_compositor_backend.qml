import QtQuick
import QtTest
import "../../services/CompositorBackend.js" as Backend

TestCase {
    name: "CompositorBackend"

    function test_compositorIdentifiersAreNormalized() {
        compare(Backend.kindForDesktop("Hyprland:wlroots"), "hyprland")
        compare(Backend.kindForDesktop("mango"), "mango")
        compare(Backend.kindForDesktop("labwc"), "labwc")
        compare(Backend.kindForDesktop("unknown:wlroots"), "wayland")
    }

    function test_hyprlandNativeFeaturesAreDetectedWithoutAffectingWaylandProtocolUse() {
        compare(Backend.hasHyprlandNativeFeatures("Hyprland"), true)
        compare(Backend.hasHyprlandNativeFeatures("mango"), false)
        compare(Backend.hasHyprlandNativeFeatures("labwc"), false)
    }
}
