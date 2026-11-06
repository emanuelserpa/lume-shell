import QtQuick

Item {
    id: root
    width: 0
    height: 0

    property var searchLogic
    property var normalizer
    property var actions
    property var commandsCatalog

    AppsProvider { id: apps }
    WindowsProvider { id: windows }
    CommandsProvider { id: commands }
    SpotlightRanking { id: ranking }

    function searchApps(query, entries, usage) {
        return apps.search(query, entries, usage, root.searchLogic, root.normalizer, root.actions)
    }

    function searchWindows(query, items) {
        return windows.search(query, items, root.searchLogic, root.normalizer, root.actions)
    }

    function searchCloseWindows(query, items) {
        return windows.searchClose(query, items, root.searchLogic, root.normalizer, root.actions)
    }

    function searchShell(command) {
        return commands.searchShell(command, root.searchLogic, root.normalizer, root.actions)
    }

    function searchActions(query) {
        return commands.searchActions(query, root.commandsCatalog, root.searchLogic, root.normalizer, root.actions)
    }

    function searchUniversal(query, entries, usage, windowsItems) {
        const q = String(query ?? "").trim()
        if (!q)
            return searchApps("", entries, usage)
        const appItems = searchApps(q, entries, usage)
        const windowItems = searchWindows(q, windowsItems).filter(item => item.kind === "window")
        const actionItems = searchActions(q).filter(item => item.kind !== "config_category")
        return ranking.merge(q, appItems, windowItems, actionItems)
    }
}
