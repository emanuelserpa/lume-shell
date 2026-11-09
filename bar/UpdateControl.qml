import QtQuick
import qs.components
import qs.services
import "../services/UpdateAvailability.js" as UpdateAvailability

Item {
    id: root

    required property var theme
    property bool plain: false

    readonly property int updateCount: UpdateState.totalUpdates
    readonly property bool updating: UpdateState.updateRunning
    readonly property bool available: UpdateAvailability.shouldShowIndicator(
        updateCount, updating, UpdateState.updateResult)
    readonly property bool showingSavedResult: updateCount === 0
        && !updating && UpdateState.updateResult.length > 0

    function togglePopup() {
        updatePopup.visible = !updatePopup.visible
    }

    visible: available
    implicitWidth: available ? pill.implicitWidth : 0
    implicitHeight: root.theme.pillHeight

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: ""
        tablerIcon: "bar-refresh"
        iconSize: root.theme.barIconSize
        fontPixelSize: root.theme.iconTokens.lg
        spinning: root.updating && root.theme.qmlAnimationsEnabled
        textColor: root.updating ? root.theme.primary
            : root.showingSavedResult
                ? (UpdateState.updateSucceeded ? root.theme.green : root.theme.red)
                : root.theme.yellow
        highlighted: updatePopup.visible || root.updating
        tooltipText: root.updating
            ? UpdateState.updateMessage
            : root.updateCount > 0
                ? root.updateCount + (root.updateCount === 1
                ? " atualização disponível"
                : " atualizações disponíveis")
                : root.showingSavedResult
                    ? (UpdateState.updateSucceeded
                        ? "Última atualização concluída: "
                        : "Última atualização falhou: ") + UpdateState.updateResult
                    : "Sem atualizações disponíveis"

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.togglePopup()
        }
    }

    SystemUpdatePopup {
        id: updatePopup
        theme: root.theme
        target: pill
        repoData: UpdateState.repoData
        aurData: UpdateState.aurData
        flatpakData: UpdateState.flatpakData
        brewData: UpdateState.brewData
        appImageData: UpdateState.appImageData
        updateRunning: UpdateState.updateRunning
        updateMessage: UpdateState.updateMessage
        updateSucceeded: UpdateState.updateSucceeded
        updateStage: UpdateState.updateStage
        updateStageCount: UpdateState.updateStageCount
        updateProgress: UpdateState.updateProgress

        onRefreshRequested: UpdateState.refreshUpdates()
        onUpdateRequested: function(backend) { UpdateState.startUpdate(backend) }
    }
}
