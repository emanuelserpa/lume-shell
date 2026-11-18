pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs
import qs.lockscreen

ShellRoot {
    id: root

    Theme {
        id: lumeTheme
    }

    QtObject {
        id: previewSession
        readonly property bool secure: true
        readonly property bool locked: true
    }

    QtObject {
        id: previewAuth
        readonly property var sessionLock: previewSession
        readonly property bool canStartAuthentication: false
        readonly property bool fingerprintActive: true
        readonly property bool passwordActive: false
        property string status: "Prévia visual — autenticação desativada"
        property bool passwordPromptVisible: false
        signal clearInputRequested()

        function submitPassword(_password) {
            status = "Prévia visual — autenticação desativada"
            passwordPromptVisible = false
            clearInputRequested()
        }

        function startAuthentication() {}

        function requestFingerprintAuthentication() {
            status = "Prévia visual — autenticação desativada"
            passwordPromptVisible = false
        }

        function requestPasswordAuthentication() {
            status = "Prévia visual — autenticação desativada"
            passwordPromptVisible = true
        }
    }

    Window {
        id: previewWindow
        visible: true
        visibility: Window.FullScreen
        color: lumeTheme.backgroundOpaque
        title: "Prévia do lockscreen Lume"

        LockSurface {
            anchors.fill: parent
            auth: previewAuth
            theme: lumeTheme
        }

        Shortcut {
            sequence: "Escape"
            onActivated: Qt.quit()
        }
    }
}
