import QtQuick
import QtTest
import "../../launcher/AppIconResolver.js" as AppIconResolver

TestCase {
    name: "AppIconResolver"

    function test_keepsResolvedThemeIcons() {
        compare(AppIconResolver.resolve("firefox", "/icons/firefox.png"), "/icons/firefox.png")
    }

    function test_usesElecwhatPackagedIconWhenThemeLookupMisses() {
        compare(AppIconResolver.resolve("elecwhat", ""),
                "file:///usr/share/icons/hicolor/256x256/apps/elecwhat.png")
        compare(AppIconResolver.resolve("ElecWhat", null),
                "file:///usr/share/icons/hicolor/256x256/apps/elecwhat.png")
    }

    function test_keepsMissingIconsOnTheExistingFallback() {
        compare(AppIconResolver.resolve("unknown-app", ""), "")
    }
}
