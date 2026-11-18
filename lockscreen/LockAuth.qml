pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    required property var sessionLock

    property string status: "Aguardando a confirmação de bloqueio do compositor…"
    property string pendingPassword: ""
    property bool pendingResponse: false
    property bool passwordPromptVisible: false

    readonly property bool fingerprintActive: fingerprintPam.active
    readonly property bool passwordActive: passwordPam.active
    readonly property bool busy: fingerprintPam.active || passwordPam.active
    signal clearInputRequested()

    function startAuthentication() {
        if (!sessionLock.secure || !sessionLock.locked || fingerprintPam.active)
            return

        status = "Leitor de impressão digital ativo."
        if (!fingerprintPam.start())
            status = "Não foi possível iniciar o leitor. A sessão continua bloqueada."
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

    function requestPasswordAuthentication() {
        if (!sessionLock.secure || !sessionLock.locked)
            return

        passwordPromptVisible = true
        if (passwordPam.active)
            return

        status = "Digite sua senha e pressione Enter."
        if (!passwordPam.start())
            status = "Não foi possível iniciar a senha. A sessão continua bloqueada."
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

        if (result === PamResult.Failed || result === PamResult.MaxTries)
            status = "Digital não reconhecida. Toque no leitor para tentar novamente ou use a senha."
        else
            status = "Leitor indisponível. Toque no ícone para tentar novamente ou use a senha."
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
            if (fingerprintPam.active)
                root.status = "Leitor de impressão digital ativo. Coloque o dedo quando quiser."
        }
        onCompleted: result => root.handleFingerprintCompleted(result)
        onError: error => {
            console.warn("Lume lock: fingerprint PAM error", PamError.toString(error))
            root.status = "Leitor indisponível. Toque no ícone para tentar novamente ou use a senha."
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
