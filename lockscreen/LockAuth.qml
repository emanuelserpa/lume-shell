pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    required property var sessionLock

    property string status: "Aguardando a confirmação de bloqueio do compositor…"
    property string pendingPassword: ""
    property bool pendingResponse: false
    property bool passwordPromptVisible: true
    property int fingerprintRetryDelay: 1000
    property bool fingerprintRecoveryPending: false

    readonly property bool fingerprintActive: fingerprintPam.active
    readonly property bool passwordActive: passwordPam.active
    readonly property bool busy: fingerprintPam.active || passwordPam.active
    signal clearInputRequested()
    signal systemResumed()

    function startAuthentication() {
        if (!sessionLock.secure || !sessionLock.locked || fingerprintPam.active)
            return

        fingerprintRetryTimer.stop()
        status = "Leitor de impressão digital ativo."
        if (!fingerprintPam.start()) {
            status = "Não foi possível iniciar o leitor. A sessão continua bloqueada."
            scheduleFingerprintRetry()
        }
    }

    function scheduleFingerprintRetry() {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        fingerprintRetryTimer.interval = fingerprintRetryDelay
        fingerprintRetryTimer.restart()
        fingerprintRetryDelay = Math.min(fingerprintRetryDelay * 2, 30000)
    }

    function retryFingerprintAuthentication() {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        // A PAM conversation should have completed before its retry timer
        // fires. Keep the lock secure if a backend leaves it active anyway.
        if (fingerprintPam.active) {
            scheduleFingerprintRetry()
            return
        }

        startAuthentication()
    }

    function handleSleepMonitorLine(line) {
        if (/PrepareForSleep\s*\(false\s*,?\s*\)/.test(line)) {
            root.systemResumed()
            recoverFingerprintAfterResume()
        }
    }

    function recoverFingerprintAfterResume() {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        fingerprintRecoveryPending = true
        fingerprintRetryTimer.stop()
        fingerprintResumeTimer.stop()
        status = "Reconectando o leitor após a suspensão…"
        // The old PAM conversation can still refer to the pre-suspend fprintd
        // owner/device. Retire it before starting a fresh conversation.
        if (fingerprintPam.active)
            fingerprintPam.abort()
        fingerprintResumeTimer.start()
    }

    function restartFingerprintAfterResume() {
        if (!sessionLock.secure || !sessionLock.locked) {
            fingerprintRecoveryPending = false
            return
        }

        fingerprintRecoveryPending = false
        fingerprintRetryDelay = 1000
        if (fingerprintPam.active) {
            fingerprintPam.abort()
            scheduleFingerprintRetry()
            return
        }

        startAuthentication()
    }

    function requestFingerprintAuthentication() {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        // A running scan already accepts a finger at any time, including
        // while the password conversation is active.
        if (fingerprintPam.active)
            return

        startAuthentication()
    }

    function submitPassword(password) {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        if (password.length === 0) {
            if (passwordPam.active && passwordPam.responseRequired) {
                status = "Digite sua senha e pressione Enter."
            } else if (!fingerprintPam.active) {
                requestFingerprintAuthentication()
            } else {
                status = "O leitor continua ativo. Coloque o dedo ou digite sua senha."
            }
            return
        }

        // Keep the response only until the password PAM conversation asks
        // for it. Credentials never enter a process argument or persistent data.
        pendingPassword = password
        pendingResponse = true
        passwordPromptVisible = true
        clearInputRequested()

        if (!passwordPam.active) {
            if (!passwordPam.start()) {
                clearPendingPassword()
                status = "Não foi possível iniciar a senha. A sessão continua bloqueada."
            }
            return
        }

        if (passwordPam.responseRequired)
            answerPasswordPrompt()
        else
            status = "Verificando senha… A leitura da digital continua ativa."
    }

    function answerPasswordPrompt() {
        if (!passwordPam.active || !passwordPam.responseRequired || !pendingResponse)
            return

        const response = pendingPassword
        clearPendingPassword()
        passwordPam.respond(response)
        status = "Verificando senha… A leitura da digital continua ativa."
    }

    function clearPendingPassword() {
        pendingPassword = ""
        pendingResponse = false
    }

    function handlePasswordPamMessage() {
        if (!passwordPam.responseRequired)
            return

        passwordPromptVisible = true
        if (pendingResponse)
            answerPasswordPrompt()
        else
            status = "Digite sua senha e pressione Enter. A digital continua ativa."
    }

    function unlock(result) {
        if (result !== PamResult.Success || !sessionLock.secure || !sessionLock.locked)
            return false

        clearPendingPassword()
        clearInputRequested()
        fingerprintRetryTimer.stop()
        fingerprintResumeTimer.stop()
        fingerprintRecoveryPending = false
        status = "Autenticado. Desbloqueando…"
        // This is the only path that releases the compositor lock.
        fingerprintPam.abort()
        passwordPam.abort()
        sessionLock.locked = false
        Qt.callLater(Qt.quit)
        return true
    }

    function handleFingerprintCompleted(result) {
        if (unlock(result))
            return

        if (fingerprintRecoveryPending)
            return

        if (result === PamResult.Failed || result === PamResult.MaxTries)
            status = "Leitor reiniciando. Toque no leitor ou use a senha."
        else
            status = "Leitor indisponível. Tentando reconectar; você também pode usar a senha."

        scheduleFingerprintRetry()
    }

    function handlePasswordCompleted(result) {
        clearPendingPassword()
        clearInputRequested()

        if (unlock(result))
            return

        status = result === PamResult.Failed || result === PamResult.MaxTries
               ? "Senha incorreta. Tente novamente ou use a digital."
               : "Erro na senha. A leitura da digital continua ativa."
        passwordPromptVisible = true
    }

    PamContext {
        id: fingerprintPam
        config: "lumeshell-lock"

        onPamMessage: {
            if (fingerprintPam.active && !root.fingerprintRecoveryPending) {
                fingerprintRetryTimer.stop()
                root.fingerprintRetryDelay = 1000
                root.status = "Leitor de impressão digital ativo. Coloque o dedo quando quiser."
            }
        }
        onCompleted: result => root.handleFingerprintCompleted(result)
        onError: error => {
            console.warn("Lume lock: fingerprint PAM error", PamError.toString(error))
            if (root.fingerprintRecoveryPending)
                return
            root.status = "Leitor indisponível. Tentando reconectar; você também pode usar a senha."
            root.scheduleFingerprintRetry()
        }
    }

    Timer {
        id: fingerprintRetryTimer
        repeat: false
        onTriggered: root.retryFingerprintAuthentication()
    }

    Timer {
        id: fingerprintResumeTimer
        interval: 1000
        repeat: false
        onTriggered: root.restartFingerprintAfterResume()
    }

    Process {
        id: sleepSignalMonitor
        command: [
            "/usr/bin/gdbus", "monitor", "--system",
            "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"
        ]
        running: root.sessionLock.secure && root.sessionLock.locked

        stdout: SplitParser {
            onRead: line => root.handleSleepMonitorLine(line)
        }
    }

    PamContext {
        id: passwordPam
        config: "lumeshell-lock-password"

        onPamMessage: root.handlePasswordPamMessage()
        onCompleted: result => root.handlePasswordCompleted(result)
        onError: error => {
            console.warn("Lume lock: password PAM error", PamError.toString(error))
            root.clearPendingPassword()
            root.clearInputRequested()
            root.status = "Erro na senha. A leitura da digital continua ativa."
            root.passwordPromptVisible = true
        }
    }
}
