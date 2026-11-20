import QtQuick
import QtTest
import "../../services/IconSource.js" as IconSource

TestCase {
    name: "IconSource"

    function test_resolvesQuickshellThemeIconUrlsToFiles() {
        compare(IconSource.resolve("image://icon/kitty", function(name, check) {
            compare(name, "kitty")
            verify(check)
            return "/usr/share/icons/hicolor/256x256/apps/kitty.png"
        }), "/usr/share/icons/hicolor/256x256/apps/kitty.png")
    }

    function test_decodesEscapedThemeIconNames() {
        compare(IconSource.resolve("image://icon/audio%2Dx%2Dgeneric", function(name) {
            return name
        }), "audio-x-generic")
    }

    function test_preservesNonThemeIconSources() {
        compare(IconSource.resolve("file:///tmp/icon.png", function() { fail() }),
                "file:///tmp/icon.png")
        compare(IconSource.resolve("qs:/assets/icon.svg", function() { fail() }),
                "qs:/assets/icon.svg")
    }

    function test_unresolvableThemeIconBecomesEmptySource() {
        compare(IconSource.resolve("image://icon/missing", function() { return "" }), "")
        compare(IconSource.resolve("image://icon/invalid%ZZ", function() { return "/never" }), "")
    }
}
