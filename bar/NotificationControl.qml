import QtQuick
import qs.bar
import qs.components
import qs.services

Item {
    id: root

    required property var theme
    property bool plain: false

    implicitWidth: pill.implicitWidth
    implicitHeight: root.theme.pillHeight

    readonly property int notificationCount: NotificationState.count
    readonly property bool dnd: NotificationState.dnd
    readonly property bool hasCritical: NotificationState.hasCritical

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: ""
        tablerIcon: "bar-controls"
        iconSize: root.theme.barIconSize
        fontPixelSize: root.theme.iconTokens.lg
        textColor: {
            if (root.hasCritical) return root.theme.red
            if (root.dnd) return root.theme.surfaceVariantForeground
            if (root.notificationCount > 0) return root.theme.primary
            return root.theme.offWhite
        }
        highlighted: notificationPopup.visible || recordingPopup.visible || root.hasCritical

        Rectangle {
            visible: root.notificationCount > 0
            width: root.theme.spacingTokens.xsPlus
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: root.theme.spacingTokens.micro
            anchors.topMargin: root.theme.spacingTokens.micro
            color: root.hasCritical ? root.theme.red : root.theme.primary
        }

        tooltipText: {
            let text = "Notificações e controles rápidos"
            if (root.notificationCount > 0)
                text = root.notificationCount === 1
                    ? "1 notificação"
                    : root.notificationCount + " notificações"
            if (root.dnd)
                text += " · Não perturbe"
            return text
        }

        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                notificationPopup.toggle()
            } else if (mouse.button === Qt.RightButton) {
                NotificationState.toggleDnd()
            }
        }
    }

    Connections {
        target: NotificationState
        function onTogglePopupRequested() {
            notificationPopup.toggle()
        }
    }

    Connections {
        target: ScreenRecordingState
        function onRecordingStopped() {
            recordingPopup.visible = false
        }
        function onStartFailed() {
            recordingPopup.visible = true
        }
    }

    NotificationPopup {
        id: notificationPopup
        theme: root.theme
        target: pill
        onOpenRecordingDetailsRequested: recordingPopup.visible = true
    }

    ScreenRecordingPopup {
        id: recordingPopup
        theme: root.theme
        target: pill
        recording: ScreenRecordingState.recording
        hasAudio: ScreenRecordingState.hasAudio
        audioMode: ScreenRecordingState.audioMode
        busy: ScreenRecordingState.busy
        elapsedText: ScreenRecordingState.elapsedText
        errorText: ScreenRecordingState.errorText
        savedPath: ScreenRecordingState.lastSaved
        onStartRequested: function(mode, selectedAudioMode) {
            recordingPopup.visible = false
            ScreenRecordingState.requestStart(mode, selectedAudioMode)
        }
        onStopRequested: ScreenRecordingState.stop()
    }
}
