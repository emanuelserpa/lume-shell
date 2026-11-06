pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

Item {
    id: root

    required property var theme
    property bool dndActive: NotificationState.dnd
    property bool caffeineActive: IdleState.inhibited
    property bool recordingActive: ScreenRecordingState.recording
    property bool recordingHasAudio: ScreenRecordingState.hasAudio
    property string recordingElapsedText: ScreenRecordingState.elapsedText

    signal stopRecordingRequested()

    readonly property bool hasActiveIndicators: root.dndActive || root.caffeineActive || root.recordingActive
    readonly property string resolvedElapsedText: root.recordingElapsedText.length > 0
                                                  ? root.recordingElapsedText
                                                  : "0:00"

    function deactivate(indicatorId) {
        if (indicatorId === "dnd") {
            NotificationState.dnd = false
        } else if (indicatorId === "caffeine") {
            IdleState.inhibited = false
        } else if (indicatorId === "recording") {
            ScreenRecordingState.stop()
            root.stopRecordingRequested()
        }
    }

    visible: hasActiveIndicators
    implicitWidth: hasActiveIndicators ? indicatorRow.implicitWidth : 0
    implicitHeight: root.theme.pillHeight

    Row {
        id: indicatorRow
        anchors.centerIn: parent
        spacing: root.theme.spacingTokens.xsPlus

        Pill {
            id: dndPill
            visible: root.dndActive
            width: root.theme.barIndicatorSize
            theme: root.theme
            plain: true
            text: ""
            tablerIcon: "bar-moon"
            iconSize: root.theme.barIconSize
            textColor: root.theme.primary
            fontPixelSize: root.theme.iconTokens.lg
            tooltipText: "Não perturbe ativado • Clique para desativar"
            activeFocusOnTab: visible
            highlighted: activeFocus

            Keys.onReturnPressed: root.deactivate("dnd")
            Keys.onEnterPressed: root.deactivate("dnd")
            Keys.onSpacePressed: root.deactivate("dnd")

            mouseArea.onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    root.deactivate("dnd")
            }
        }

        Pill {
            id: caffeinePill
            visible: root.caffeineActive
            width: root.theme.barIndicatorSize
            theme: root.theme
            plain: true
            text: ""
            tablerIcon: "bar-coffee"
            iconSize: root.theme.barIconSize
            textColor: root.theme.yellow
            fontPixelSize: root.theme.iconTokens.lg
            tooltipText: "Suspensão inibida • Clique para desativar"
            activeFocusOnTab: visible
            highlighted: activeFocus

            Keys.onReturnPressed: root.deactivate("caffeine")
            Keys.onEnterPressed: root.deactivate("caffeine")
            Keys.onSpacePressed: root.deactivate("caffeine")

            mouseArea.onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    root.deactivate("caffeine")
            }
        }

        Pill {
            id: recordingPill
            visible: root.recordingActive
            width: implicitWidth + 4
            radius: height / 2
            theme: root.theme
            plain: true
            color: root.theme.withAlpha(
                root.theme.red,
                (mouseArea.containsMouse || activeFocus) ? 0.22 : 0.14
            )
            text: root.resolvedElapsedText
            tablerIcon: root.recordingHasAudio ? "bar-record-audio" : "bar-record"
            iconSize: root.theme.barIconSize
            textColor: root.theme.red
            fontFamily: root.theme.fontFamily
            fontPixelSize: root.theme.typeTokens.subtitle
            tooltipText: (root.recordingHasAudio
                          ? "Gravando tela com áudio (" + root.resolvedElapsedText + ")"
                          : "Gravação de tela ativa (" + root.resolvedElapsedText + ")")
                         + " • Clique para parar"
            activeFocusOnTab: visible
            highlighted: activeFocus

            Keys.onReturnPressed: root.deactivate("recording")
            Keys.onEnterPressed: root.deactivate("recording")
            Keys.onSpacePressed: root.deactivate("recording")

            mouseArea.onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    root.deactivate("recording")
            }
        }
    }
}
