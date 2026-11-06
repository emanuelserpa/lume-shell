// LEGADO: pill de gravação de tela autônoma não montada por padrão em bar/Bar.qml
// (o estado compartilhado vive em services/ScreenRecordingState.qml, com disparo em NotificationControl e indicador ativo em StatusIsland).
import QtQuick
import qs.components
import qs.services

Item {
    id: root

    required property var theme
    property bool plain: false
    property Item popupTarget: null
    implicitWidth: pill.implicitWidth
    implicitHeight: root.theme.pillHeight

    readonly property bool recording: ScreenRecordingState.recording
    readonly property bool hasAudio: ScreenRecordingState.hasAudio
    readonly property int elapsed: ScreenRecordingState.elapsed
    readonly property string elapsedText: ScreenRecordingState.elapsedText
    readonly property bool busy: ScreenRecordingState.busy

    function stop() {
        ScreenRecordingState.stop()
    }

    function openPopup() {
        popup.visible = true
    }

    Connections {
        target: ScreenRecordingState
        function onRecordingStopped() {
            popup.visible = false
        }
        function onStartFailed() {
            popup.visible = true
        }
    }

    Pill {
        id: pill
        anchors.fill: parent
        theme: root.theme
        plain: root.plain
        text: root.recording ? root.elapsedText : ""
        tablerIcon: root.recording && root.hasAudio ? "bar-record-audio" : "bar-record"
        iconSize: root.theme.barIconSize
        fontFamily: root.theme.fontFamily
        fontPixelSize: root.theme.iconTokens.lg
        textColor: root.recording ? root.theme.red : root.theme.offWhite
        highlighted: popup.visible || root.recording
        tooltipText: ScreenRecordingState.errorText.length > 0
            ? "Falha na gravação"
            : (root.recording
               ? (root.hasAudio ? "Gravando tela com áudio" : "Gravação de tela ativa")
               : "Gravar tela")
        mouseArea.onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                popup.visible = !popup.visible
        }
    }

    ScreenRecordingPopup {
        id: popup
        theme: root.theme
        target: root.popupTarget ? root.popupTarget : pill
        recording: root.recording
        hasAudio: root.hasAudio
        audioMode: ScreenRecordingState.audioMode
        busy: root.busy
        elapsedText: root.elapsedText
        errorText: ScreenRecordingState.errorText
        savedPath: ScreenRecordingState.lastSaved
        onStartRequested: function(mode, selectedAudioMode) {
            popup.visible = false
            ScreenRecordingState.requestStart(mode, selectedAudioMode)
        }
        onStopRequested: ScreenRecordingState.stop()
    }
}
