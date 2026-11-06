pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.components
import "CommandResult.js" as CommandResult

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property string activeProfile: "balanced"
    property string activeLabel: "Balanceado"
    property var profiles: [
        { id: "performance", label: "Performance" },
        { id: "balanced", label: "Balanceado" },
        { id: "power-saver", label: "Economia" }
    ]
    property bool available: true
    property bool busy: false
    property bool awaitingNativeProfile: false
    property string requestedNativeProfile: ""
    property string error: ""
    property var statusData: ({})

    function profileValue(profileId) {
        if (profileId === "performance") return PowerProfile.Performance
        if (profileId === "power-saver") return PowerProfile.PowerSaver
        return PowerProfile.Balanced
    }

    function profileId(profile) {
        if (profile === PowerProfile.Performance) return "performance"
        if (profile === PowerProfile.PowerSaver) return "power-saver"
        return "balanced"
    }

    function refresh() {
        statusState.refresh()
    }

    function applyStatus(res) {
        if (!res)
            return
        if (!res.ok) {
            root.available = false
            root.error = String(res.error ?? "Perfis de energia indisponíveis.")
            return
        }
        const data = res.data ?? ({})
        root.statusData = data
        root.available = Boolean(data.available)
        root.activeProfile = String(data.active ?? "balanced")
        if (data.profiles && data.profiles.length > 0)
            root.profiles = data.profiles
        const match = root.profiles.find(p => p.id === root.activeProfile)
        root.activeLabel = match ? match.label : root.activeProfile
        root.error = ""
    }

    function setProfile(profileId) {
        if (root.statusData.backend === "power-profiles-daemon") {
            if (profileId === "performance" && !PowerProfiles.hasPerformanceProfile) {
                root.error = "O perfil Performance não está disponível neste dispositivo."
                return
            }
            root.busy = true
            root.awaitingNativeProfile = true
            root.requestedNativeProfile = profileId
            root.error = ""
            if (PowerProfiles.profile === root.profileValue(profileId)) {
                root.busy = false
                root.awaitingNativeProfile = false
                root.requestedNativeProfile = ""
                return
            }
            PowerProfiles.profile = root.profileValue(profileId)
            return
        }
        if (setProc.running)
            return
        root.busy = true
        root.error = ""
        setProc.command = ["python3", "-B", Quickshell.shellDir + "/scripts/energy-profile.py", "set", profileId]
        setProc.running = true
    }

    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            if (root.statusData.backend !== "power-profiles-daemon")
                return
            const active = root.profileId(PowerProfiles.profile)
            root.activeProfile = active
            const match = root.profiles.find(profile => profile.id === active)
            root.activeLabel = match ? match.label : active
            root.statusData = Object.assign({}, root.statusData, {active: active})
            if (!root.awaitingNativeProfile || active === root.requestedNativeProfile) {
                root.busy = false
                root.awaitingNativeProfile = false
                root.requestedNativeProfile = ""
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        repeat: false
        running: root.awaitingNativeProfile
        onTriggered: {
            root.busy = false
            root.awaitingNativeProfile = false
            root.requestedNativeProfile = ""
            root.error = "Não foi possível confirmar a alteração do perfil."
        }
    }

    CommandJson {
        id: statusState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/energy-profile.py", "status"]
        interval: 0
        onResultChanged: root.applyStatus(statusState.result)
    }

    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                try {
                    const res = CommandResult.decode(this.text)
                    if (!res.ok)
                        root.error = res.error
                    else
                        root.applyStatus(res)
                } catch (e) {
                    root.error = "Resposta inválida ao alterar o perfil."
                }
                refreshTimer.restart()
            }
        }
    }
}
