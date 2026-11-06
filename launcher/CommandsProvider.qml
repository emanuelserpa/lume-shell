import QtQuick

QtObject {
    function searchShell(command, logic, resultModel, catalog) {
        return resultModel.normalizeAll(logic.commandResult(command), "commands", catalog)
    }

    function searchActions(query, actionCatalog, logic, resultModel, catalog) {
        const q = logic.normalize(query)
        if (q.length === 0)
            return resultModel.normalizeAll(actionCatalog.configCategories(), "commands", catalog)
        const categories = actionCatalog.configCategories().filter(item =>
            logic.normalize(item.title).includes(q) || logic.normalize(item.subtitle).includes(q))
        const actions = actionCatalog.allSettingsActions().filter(item =>
            logic.normalize(item.title).includes(q) || logic.normalize(item.subtitle).includes(q))
        return resultModel.normalizeAll(categories.concat(actions), "commands", catalog)
    }
}
