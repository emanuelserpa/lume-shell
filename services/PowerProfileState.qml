pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.components
import "CommandResult.js" as CommandResult
import "BatteryPowerPolicy.js" as BatteryPowerPolicy

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property string activeProfile: "balanced"
    property string activeLabel: "Equilibrado"
    property var profiles: [
        { id: "extra-low-power", label: "Ultra Eco", icon: "leaf" },
        { id: "power-saver", label: "Economia" },
        { id: "balanced", label: "Equilibrado" },
        { id: "performance", label: "Desempenho" }
    ]
    property bool available: true
    property bool busy: false
    property bool statusReady: false
    property bool awaitingNativeProfile: false
    property string requestedNativeProfile: ""
    property string error: ""
    property var statusData: ({})
    property var policyState: ({
        autoApplied: false,
        manualOverride: false,
        wasPlugged: false,
        previousProfile: "balanced"
    })
    readonly property var battery: UPower.displayDevice
    readonly property bool isExtraLowPower: root.activeProfile === "extra-low-power"
    readonly property bool isAutoActivated: Boolean(root.statusData?.auto_activated) || Boolean(root.policyState?.autoApplied)

    function profileValue(profileId) {
        if (profileId === "performance") return PowerProfile.Performance
        if (profileId === "power-saver" || profileId === "extra-low-power") return PowerProfile.PowerSaver
        return PowerProfile.Balanced
    }

    function profileId(profile) {
        if (profile === PowerProfile.Performance) return "performance"
        if (profile === PowerProfile.PowerSaver) return "power-saver"
        return "balanced"
    }

    function batteryPercentage() {
        const device = root.battery
        if (!device || !device.ready) return 100
        return Math.floor(device.percentage * 100)
    }

    function isPlugged() {
        const device = root.battery
        if (!device || !device.ready) return false
        return device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged
    }

    function isDischarging() {
        const device = root.battery
        if (!device || !device.ready) return false
        return device.state === UPowerDeviceState.Discharging
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
        root.statusReady = true
        root.statusData = data
        root.available = Boolean(data.available)
        root.activeProfile = String(data.active ?? "balanced")
        if (data.profiles && data.profiles.length > 0)
            root.profiles = data.profiles
        const match = root.profiles.find(p => p.id === root.activeProfile)
        root.activeLabel = match ? match.label : root.activeProfile
        if (data.extra_low_power) {
            root.policyState = ({
                autoApplied: Boolean(data.auto_activated) || Boolean(root.policyState.autoApplied),
                manualOverride: Boolean(root.policyState.manualOverride),
                wasPlugged: Boolean(root.policyState.wasPlugged),
                previousProfile: String(data.previous_profile || root.policyState.previousProfile || "balanced")
            })
        } else {
            root.policyState = ({
                autoApplied: false,
                manualOverride: Boolean(root.policyState.manualOverride),
                wasPlugged: Boolean(root.policyState.wasPlugged),
                previousProfile: String(root.policyState.previousProfile || "balanced")
            })
        }
        root.error = ""
        root.evaluateBatteryPolicy()
    }

    function setProfile(profileId) {
        root.policyState = BatteryPowerPolicy.noteManualSelection(
            root.policyState, profileId, root.batteryPercentage(), root.isPlugged())
        root.applyProfile(profileId, false)
    }

    function applyProfile(profileId, auto) {
        const involvesExtra = profileId === "extra-low-power"
            || root.activeProfile === "extra-low-power"
            || Boolean(root.statusData?.extra_low_power)

        if (root.statusData.backend === "power-profiles-daemon" && !involvesExtra) {
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
        const args = ["python3", "-B", Quickshell.shellDir + "/scripts/energy-profile.py", "set", profileId]
        if (auto && profileId === "extra-low-power")
            args.push("--auto")
        setProc.command = args
        setProc.running = true
    }

    function evaluateBatteryPolicy() {
        const device = root.battery
        if (!root.statusReady || !root.available || root.busy || !device || !device.ready)
            return
        const decision = BatteryPowerPolicy.evaluateBatteryTransition(
            root.policyState,
            root.batteryPercentage(),
            root.isDischarging(),
            root.isPlugged(),
            root.activeProfile
        )
        root.policyState = ({
            autoApplied: decision.autoApplied,
            manualOverride: decision.manualOverride,
            wasPlugged: decision.wasPlugged,
            previousProfile: decision.previousProfile
        })
        if (decision.action === "activate" && decision.targetProfile) {
            root.applyProfile(decision.targetProfile, true)
        } else if (decision.action === "restore" && decision.targetProfile) {
            root.applyProfile(decision.targetProfile, false)
        }
    }

    Connections {
        target: root.battery
        function onReadyChanged() { root.evaluateBatteryPolicy() }
        function onPercentageChanged() { root.evaluateBatteryPolicy() }
        function onStateChanged() { root.evaluateBatteryPolicy() }
    }

    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            if (root.statusData.backend !== "power-profiles-daemon")
                return
            const active = root.profileId(PowerProfiles.profile)
            if (root.statusData?.extra_low_power) {
                if (active === "power-saver")
                    return
                // System policy switched PPD away from power-saver (e.g. AC plugged):
                // ensure the CPU frequency cap and saved boost are also restored.
                root.applyProfile(active, false)
                return
            }
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
