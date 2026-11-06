pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import "AppCategoryLogic.js" as CategoryLogic

Item {
    id: root

    required property var theme
    required property var applications
    required property string selectedCategory

    signal categorySelected(string categoryId)
    signal categoryHighlighted(string categoryId)

    function ensureSelectedVisible() {
        const categoryIndex = CategoryLogic.categories.findIndex(
            category => category.id === root.selectedCategory)
        if (categoryIndex < 0)
            return

        const row = categoryRepeater.itemAt(categoryIndex)
        if (!row || !row.visible)
            return

        const rowTop = row.mapToItem(categoryFlick.contentItem, 0, 0).y
        const rowBottom = rowTop + row.height
        if (rowTop < categoryFlick.contentY)
            categoryFlick.contentY = rowTop
        else if (rowBottom > categoryFlick.contentY + categoryFlick.height)
            categoryFlick.contentY = rowBottom - categoryFlick.height
    }

    onSelectedCategoryChanged: Qt.callLater(root.ensureSelectedVisible)
    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.ensureSelectedVisible)
    }

    function moveSelection(direction) {
        const available = CategoryLogic.categories.filter(category =>
            category.id === "all"
            || root.applications.some(entry => CategoryLogic.matchesCategory(entry, category.id)))
        if (available.length === 0)
            return

        let index = available.findIndex(category => category.id === root.selectedCategory)
        if (index < 0)
            index = 0
        index = Math.max(0, Math.min(available.length - 1, index + direction))
        root.categoryHighlighted(available[index].id)
    }

    Flickable {
        id: categoryFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: categoryList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelKinetic { scrollTarget: categoryFlick }

        Column {
            id: categoryList
            width: parent.width
            spacing: root.theme.spacingTokens.tiny

            Repeater {
                id: categoryRepeater
                model: CategoryLogic.categories

                delegate: PopupListRow {
                    id: categoryRow
                    required property var modelData
                    theme: root.theme
                    readonly property int appCount: root.applications.filter(
                        entry => CategoryLogic.matchesCategory(entry, modelData.id)).length

                    visible: appCount > 0 || modelData.id === "all"
                    rowHeight: visible ? 32 : 0
                    active: root.selectedCategory === modelData.id
                    idleColor: "transparent"
                    activeColor: root.theme.primaryContainer
                    idleBorderWidth: 0
                    activeBorderWidth: 1
                    activeBorderColor: root.theme.primary

                    leadingIcon: modelData.icon
                    leadingIconColor: active ? root.theme.primary : root.theme.foreground
                    leadingIconPixelSize: root.theme.iconTokens.mdPlus
                    title: modelData.label
                    titlePixelSize: root.theme.typeTokens.subtitle
                    titleColor: active ? root.theme.primaryContainerForeground : root.theme.offWhite
                    titleWeight: active ? Font.DemiBold : Font.Normal
                    trailing: Text {
                        text: String(categoryRow.appCount)
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                    }

                    interactionHandlers: TapHandler {
                        onTapped: root.categorySelected(categoryRow.modelData.id)
                    }
                }
            }
        }
    }
}
