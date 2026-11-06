pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../launcher" as Launcher
import "../../launcher/SpotlightModeLogic.js" as ModeLogic

TestCase {
    id: testCase
    name: "SpotlightQueryRouter"

    property string query: ""
    property var routerInstance
    property var searchControllerInstance

    Component {
        id: routerFactory

        Launcher.SpotlightQueryRouter {
            query: testCase.query
            searchLogic: ({
                normalize: function(value) { return String(value).toLowerCase() },
                calcResult: function(value) { return [{kind: "calc", value: value}] }
            })
            clipboard: ({
                available: false,
                error: "backend indisponível",
                items: [],
                loaded: false,
                fresh: true,
                thumbs: ({})
            })
            modes: ({
                fileItems: [],
                emojiAvailable: true,
                emojiItems: [],
                windowItems: []
            })
            actionCatalog: ({
                themeActions: function() {
                    return [{kind: "theme_select", title: "Tokyo Night", subtitle: "Tema escuro"}]
                },
                nightlightActions: function() { return [] },
                energyActions: function() { return [] },
                captureActions: function() {
                    return [{kind: "system", title: "Ler QR code da tela", subtitle: "Selecionar região"}]
                },
                connectionActions: function() { return [] },
                systemActionsList: function() { return [] },
                sessionActions: function() { return [] }
            })
            searchController: ({
                searchActions: function() { return [] },
                searchCloseWindows: function() { return [] },
                searchWindows: function() { return [] },
                searchShell: function() { return [] },
                searchUniversal: function() { return [] }
            })
            normalizer: ({normalizeAll: function(items) { return items }})
            actionRegistry: ({})
        }
    }

    Component {
        id: searchControllerFactory
        Launcher.SpotlightSearchController {
            searchLogic: ({
                normalize: function(value) { return String(value).toLowerCase().trim() },
                searchApps: function() { return [] },
                filterWindows: function() { return [] },
                filterKill: function() { return [] },
                commandResult: function() { return [] }
            })
            normalizer: ({
                normalizeAll: function(items, provider) {
                    return items.map(item => Object.assign({}, item, {
                        provider: provider,
                        id: item.id ?? item.title
                    }))
                }
            })
            actions: ({})
            commandsCatalog: ({
                configCategories: function() { return [] },
                allSettingsActions: function() {
                    return [{
                        kind: "app_exec",
                        title: "Mixer settings",
                        subtitle: "Open audio device controls"
                    }]
                }
            })
        }
    }

    function init() {
        routerInstance = routerFactory.createObject(testCase)
        searchControllerInstance = searchControllerFactory.createObject(testCase)
    }

    function cleanup() {
        routerInstance.destroy()
        routerInstance = null
        searchControllerInstance.destroy()
        searchControllerInstance = null
    }

    function test_emptyFileQueryReturnsHint() {
        query = "@"
        compare(routerInstance.results.length, 1)
        compare(routerInstance.results[0].kind, "hint")
        compare(routerInstance.results[0].title, "Arquivos")
    }

    function test_emojiGridReceivesAllFortyVisibleItems() {
        routerInstance.modes.emojiItems = Array.from({length: 45}, (_, index) => ({
            char: String(index),
            name: "emoji " + index
        }))
        query = ";"

        compare(routerInstance.results.length, 40)
        compare(routerInstance.results[39].emoji, "39")
    }

    function test_themeQueryFiltersCatalog() {
        query = ":tema night"
        compare(routerInstance.results.length, 1)
        compare(routerInstance.results[0].title, "Tokyo Night")
    }

    function test_modeTitleUsesQueryPrefix() {
        compare(routerInstance.getActionModeTitle(":energia bateria"), "Energia")
    }

    function test_capturePrefixFiltersCaptureActions() {
        query = ":captura qr"
        compare(routerInstance.results.length, 1)
        compare(routerInstance.results[0].title, "Ler QR code da tela")
        compare(routerInstance.getActionModeTitle(query), "Captura e compartilhamento")
    }

    function test_actionAliasesShareRouteAndTitle() {
        const aliases = [":captura qr", ":capture qr", ":qr qr"]
        for (const alias of aliases) {
            query = alias
            compare(routerInstance.results.length, 1)
            compare(routerInstance.results[0].title, "Ler QR code da tela")
            compare(routerInstance.getActionModeTitle(alias), "Captura e compartilhamento")
        }
    }

    function test_themeConfigAliasUsesThemeMode() {
        query = ":config night"

        compare(routerInstance.results.length, 1)
        compare(routerInstance.results[0].title, "Tokyo Night")
        compare(ModeLogic.modeForQuery(query), "themes")
    }

    function test_universalSearchKeepsSubtitleMatchesFromActions() {
        const results = searchControllerInstance.searchUniversal("audio", [], {}, [])

        compare(results.length, 1)
        compare(results[0].title, "Mixer settings")
        compare(results[0].subtitle, "Open audio device controls")
    }
}
