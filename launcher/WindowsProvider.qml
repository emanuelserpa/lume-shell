import QtQuick

QtObject {
    function search(query, items, logic, resultModel, catalog) {
        return resultModel.normalizeAll(logic.filterWindows(items, query), "windows", catalog)
    }

    function searchClose(query, items, logic, resultModel, catalog) {
        return resultModel.normalizeAll(logic.filterKill(items, query), "windows", catalog)
    }
}
