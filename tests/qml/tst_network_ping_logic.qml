import QtQuick
import QtTest
import "../../services/NetworkPingLogic.js" as NetworkPingLogic

TestCase {
    name: "NetworkPingLogic"

    function test_numericPingTiers() {
        const fast = NetworkPingLogic.derivePingPresentation(22, "online", true, false)
        compare(fast.label, "22 ms")
        compare(fast.tone, "good")

        const medium = NetworkPingLogic.derivePingPresentation(95, "online", true, false)
        compare(medium.label, "95 ms")
        compare(medium.tone, "warn")

        const slow = NetworkPingLogic.derivePingPresentation(210, "online", true, false)
        compare(slow.label, "210 ms")
        compare(slow.tone, "high")
    }

    function test_statusFallbacksWhenPingIsBlocked() {
        const online = NetworkPingLogic.derivePingPresentation(-1, "online", true, false)
        compare(online.label, "Online")
        compare(online.tone, "good")

        const limited = NetworkPingLogic.derivePingPresentation(-1, "limited", true, false)
        compare(limited.label, "Limitada")
        compare(limited.tone, "warn")

        const offline = NetworkPingLogic.derivePingPresentation(-1, "offline", true, false)
        compare(offline.label, "Offline")
        compare(offline.tone, "error")

        const checking = NetworkPingLogic.derivePingPresentation(-1, "unknown", false, false)
        compare(checking.label, "Verificando…")
        compare(checking.tone, "muted")

        const unavailable = NetworkPingLogic.derivePingPresentation(-1, "unknown", true, false)
        compare(unavailable.label, "Indisponível")
        compare(unavailable.tone, "muted")
    }

    function test_captivePortalOverridesIcmpPing() {
        const portal = NetworkPingLogic.derivePingPresentation(14, "online", true, true)
        compare(portal.status, "portal")
        compare(portal.pingMs, -1)
        compare(portal.label, "Portal")
        compare(portal.tone, "warn")
    }
}
