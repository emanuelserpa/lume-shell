import QtQuick
import QtTest
import "../../launcher/AppCategoryLogic.js" as CategoryLogic

TestCase {
    name: "AppCategoryLogic"

    function test_desktopEntryCategoriesMayBeListsOrSemicolonStrings() {
        compare(CategoryLogic.bucketOf({categories: ["Development"]}), "dev")
        compare(CategoryLogic.bucketOf({categories: "AudioVideo;Player;"}), "media")
    }

    function test_categoriesMatchMenuBuckets() {
        compare(CategoryLogic.matchesCategory({categories: ["Game"]}, "game"), true)
        compare(CategoryLogic.matchesCategory({categories: ["Utility"]}, "office"), false)
        compare(CategoryLogic.matchesCategory({categories: []}, "other"), true)
        compare(CategoryLogic.matchesCategory({categories: []}, "all"), true)
    }

    function test_appTagUsesTheMenuCategoryLabel() {
        compare(CategoryLogic.labelFor({categories: ["Game"]}), "Jogos")
        compare(CategoryLogic.labelFor({categories: ["Network"]}), "Rede")
        compare(CategoryLogic.labelFor({categories: ["Development"]}), "Desenvolvimento")
    }

    function test_appContextKeepsTypeAndAddsItsCategory() {
        compare(CategoryLogic.contextLabel("Jogos"), "Aplicativo · Jogos")
        compare(CategoryLogic.contextLabel("Rede"), "Aplicativo · Rede")
        compare(CategoryLogic.contextLabel("Aplicativo"), "Aplicativo")
    }
}
