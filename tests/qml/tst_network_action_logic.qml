import QtQuick
import QtTest
import "../../services/NetworkActionLogic.js" as NetworkActionLogic

TestCase {
    name: "NetworkActionLogic"

    function test_vpnSwitchProducesTheRequestedState() {
        compare(JSON.stringify(NetworkActionLogic.vpnSetArguments("profile-id", true)),
                JSON.stringify(["vpn-set", "profile-id", "on"]))
        compare(JSON.stringify(NetworkActionLogic.vpnSetArguments("profile-id", false)),
                JSON.stringify(["vpn-set", "profile-id", "off"]))
    }
}
