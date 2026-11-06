import QtQuick

QtObject {
    function search(query, entries, usage, logic, resultModel, catalog) {
        return resultModel.normalizeAll(logic.searchApps(entries, query, usage), "apps", catalog)
    }
}
