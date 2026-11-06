pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.WindowManager
import qs.components
import qs.services
import "../services/CompositorBackend.js" as CompositorBackend
import "../services/MangoWorkspace.js" as MangoWorkspace
import "../services/WorkspaceModel.js" as WorkspaceModel

Item {
    id: root
    required property var theme
    required property var screen
    property bool plain: false
    implicitWidth: row.implicitWidth
    implicitHeight: root.theme.barContentHeight

    property real wheelAccumulator: 0
    property bool wheelGestureLocked: false

    readonly property var defaultIcons: [
        "󰖟 ₁", " ₂", "󰭹 ₃", "󰎆 ₄", "󰉋 ₅",
        "󰈙 ₆", " ₇", "󰊗 ₈", "󰅩 ₉", " ₁₀"
    ]

    // Use ext-workspace-v1 through Quickshell on every compositor that
    // advertises it. Native backends below are only compatibility fallbacks.
    property int labwcDesktops: 10
    readonly property string compositor:
        CompositorBackend.kindForDesktop(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "")
    readonly property bool hyprlandActive: root.compositor === "hyprland"
    readonly property bool mangoActive: root.compositor === "mango" && MangoState.available
    readonly property int hyprlandActiveWorkspaceId: {
        const monitor = root.screen ? Hyprland.monitorFor(root.screen) : null
        return monitor?.activeWorkspace?.id ?? -1
    }

    // User icons from workspaces.json (hot-reloads on save).
    // Missing/empty slots fall back to the defaults above.
    property var customIcons: []

    function reloadIcons() {
        try {
            const obj = JSON.parse(iconsFile.text())
            const arr = obj && obj.icons
            if (Array.isArray(arr)) {
                const out = []
                for (let i = 0; i < Math.min(10, arr.length); i++) {
                    const s = String(arr[i] ?? "").trim()
                    out.push(s.length > 0 ? s : root.defaultIcons[i])
                }
                root.customIcons = out
                return
            }
        } catch (e) {}
        root.customIcons = []
    }

    readonly property var icons: {
        const out = root.defaultIcons.slice()
        for (let i = 0; i < root.customIcons.length && i < out.length; i++)
            out[i] = root.customIcons[i]
        return out
    }

    FileView {
        id: iconsFile
        path: ShellPaths.configFile("workspaces.json")
        watchChanges: true
        printErrors: false
        onLoadedChanged: root.reloadIcons()
        onFileChanged: {
            iconsFile.reload()
            root.reloadIcons()
        }
    }

    Component.onCompleted: root.reloadIcons()

    // Keep a fixed Repeater model on Hyprland. Filtering the live workspace
    // objects by active/toplevel state rebuilt the model during workspace
    // switches, destroying delegates while their active-color transition ran.
    readonly property var hyprlandWorkspaceSlots: {
        const slots = []
        for (let id = 1; id <= root.icons.length; id++)
            slots.push({ id: id })
        return slots
    }

    // qmllint disable unresolved-type
    readonly property var protocolWindowsets:
        WorkspaceModel.numericWindowsets(
            root.screen ? WindowManager.screenProjection(root.screen).windowsets : [],
            root.icons.length
        )
    // qmllint enable unresolved-type
    readonly property bool protocolWorkspacesAvailable: root.protocolWindowsets.length > 0

    // Fallback if the compositor does not expose ext-workspace.
    readonly property var labwcVisibleWorkspaces: {
        const live = root.protocolWindowsets
        if (live.length > 0)
            return live
        const n = Math.max(1, Math.min(root.labwcDesktops, root.icons.length))
        const out = []
        for (let i = 1; i <= n; i++)
            out.push({ id: i })
        return out
    }

    readonly property var mangoVisibleWorkspaces: MangoState.visibleTags(root.screen?.name ?? "")

    readonly property var visibleWorkspaces:
        root.hyprlandActive ? root.hyprlandWorkspaceSlots
        : root.mangoActive ? root.mangoVisibleWorkspaces
        : root.protocolWorkspacesAvailable ? root.protocolWindowsets
        : root.compositor === "labwc" ? root.labwcVisibleWorkspaces : []

    function focusWorkspace(selector) {
        Quickshell.execDetached([
            Quickshell.shellDir + "/scripts/compositor-dispatch.sh",
            "workspace",
            String(selector)
        ])
    }

    Timer {
        id: wheelUnlock
        interval: 240
        repeat: false
        onTriggered: {
            root.wheelGestureLocked = false
            root.wheelAccumulator = 0
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.theme.spacingTokens.xsPlus

        Repeater {
            model: root.visibleWorkspaces

            delegate: Rectangle {
                id: workspaceDelegate
                required property var modelData
                readonly property var vectorIcons: ["globe", "terminal", "message", "music", "folder", "file", "tool", "game", "code", "settings"]
                readonly property bool useVector: workspaceNumber > 0
                    && root.icons[workspaceNumber - 1] === root.defaultIcons[workspaceNumber - 1]
                readonly property color labelColor: urgent ? root.theme.backgroundOpaque
                    : active ? root.theme.primaryForeground
                    : hover.containsMouse ? root.theme.accent : root.theme.surfaceForeground
                // Protocol windowsets use numeric names; native adapters keep
                // numeric IDs. Normalize either representation before indexing.
                readonly property int workspaceNumber: WorkspaceModel.numericWorkspaceNumber(
                    modelData,
                    {
                        hyprland: root.hyprlandActive,
                        protocol: root.protocolWorkspacesAvailable,
                        mango: root.mangoActive,
                        maximum: root.icons.length
                    }
                )
                property var ws: {
                    if (!root.hyprlandActive)
                        return modelData

                    const workspaces = Hyprland.workspaces.values
                    for (let i = 0; i < workspaces.length; i++) {
                        if (workspaces[i].id === modelData.id)
                            return workspaces[i]
                    }
                    return null
                }
                property bool active: root.hyprlandActive
                    ? root.hyprlandActiveWorkspaceId === workspaceNumber
                    : ws !== null ? ws.active : false
                property bool urgent: ws !== null ? ws.urgent : false

                visible: !root.hyprlandActive
                    || active
                    || (ws !== null && ws.toplevels && ws.toplevels.values.length > 0)

                width: Math.max(root.theme.barWorkspaceMinWidth,
                                (useVector ? workspaceContent.implicitWidth : label.implicitWidth) + root.theme.barWorkspaceHorizontalPadding)
                height: root.theme.pillHeight
                radius: root.theme.pillRadius
                clip: true

                color: urgent ? root.theme.red
                              : active ? root.theme.accent
                              : root.plain ? "transparent" : root.theme.pillBackground

                border.width: root.plain ? 0 : 1
                border.color: urgent ? root.theme.red
                            : active ? root.theme.accent
                            : hover.containsMouse ? root.theme.pillBorderHover
                            : root.theme.pillBorder

                Behavior on color {
                    enabled: root.theme.qmlAnimationsEnabled
                    ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
                }
                Behavior on border.color {
                    enabled: root.theme.qmlAnimationsEnabled
                    ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.theme.stateLayer(
                        root.theme.surfaceForeground,
                        hover.pressed ? "pressed" : hover.containsMouse ? "hover" : "none"
                    )
                    Behavior on color {
                        enabled: root.theme.qmlAnimationsEnabled
                        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
                    }
                }

                Text {
                    id: label
                    visible: !workspaceDelegate.useVector
                    anchors.fill: parent
                    anchors.topMargin: -1
                    anchors.bottomMargin: 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                    text: parent.workspaceNumber > 0
                          ? root.icons[parent.workspaceNumber - 1]
                          : String(parent.ws?.name ?? parent.ws?.id ?? "")
                    color: parent.urgent ? root.theme.backgroundOpaque
                         : parent.active ? root.theme.primaryForeground
                         : hover.containsMouse ? root.theme.accent
                         : (root.theme.isLight ? root.theme.foreground : root.theme.offWhite)
                    font.family: root.theme.nerdFontFamily
                    font.pixelSize: root.theme.iconTokens.lgPlus
                    font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferFullHinting
                }

                Row {
                    id: workspaceContent
                    visible: workspaceDelegate.useVector
                    anchors.centerIn: parent
                    spacing: root.theme.spacingTokens.xs
                    TablerIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.theme.barIconSize; height: width
                        iconName: workspaceDelegate.useVector
                            ? "bar-" + workspaceDelegate.vectorIcons[workspaceDelegate.workspaceNumber - 1] : ""
                        iconColor: workspaceDelegate.labelColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: workspaceDelegate.workspaceNumber
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: workspaceDelegate.labelColor
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        // ext-workspace-v1 provides the same activation request
                        // for workspaces and tags across supported compositors.
                        if (parent.ws !== null && parent.ws.canActivate !== false
                                && typeof parent.ws.activate === "function")
                            parent.ws.activate()
                        else if (root.mangoActive)
                            MangoState.dispatchWorkspace(parent.workspaceNumber, root.screen?.name ?? "")
                        else
                            root.focusWorkspace(String(parent.workspaceNumber))
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            wheel.accepted = true

            if (wheel.phase === Qt.ScrollBegin) {
                root.wheelAccumulator = 0
                root.wheelGestureLocked = false
            }

            if (wheel.phase === Qt.ScrollEnd) {
                root.wheelAccumulator = 0
                root.wheelGestureLocked = false
                return
            }

            if (root.wheelGestureLocked) {
                wheelUnlock.restart()
                return
            }

            const hasPixelDelta = wheel.pixelDelta.y !== 0
            const delta = hasPixelDelta
                          ? wheel.pixelDelta.y
                          : wheel.angleDelta.y
            const threshold = hasPixelDelta ? 42 : 120

            if (delta === 0)
                return

            root.wheelAccumulator += delta

            if (Math.abs(root.wheelAccumulator) < threshold)
                return

            if (root.hyprlandActive) {
                // Hyprland's native workspace model and relative dispatch are
                // preferred; ext-workspace remains the fallback data source.
                root.focusWorkspace(root.wheelAccumulator > 0 ? "e-1" : "e+1")
            } else if (root.protocolWorkspacesAvailable) {
                const current = root.protocolWindowsets.find(w => w.active)
                const next = WorkspaceModel.adjacentWindowset(
                    root.protocolWindowsets,
                    current?.name ?? "",
                    root.wheelAccumulator > 0 ? -1 : 1
                )
                if (next?.canActivate)
                    next.activate()
            } else if (root.hyprlandActive) {
                root.focusWorkspace(root.wheelAccumulator > 0 ? "e-1" : "e+1")
            } else if (root.mangoActive) {
                const workspaces = MangoState.tagsForOutput(root.screen?.name ?? "")
                const active = workspaces.find(function(workspace) { return workspace.active })
                const next = MangoWorkspace.adjacentTag(
                    active?.number ?? 0,
                    root.wheelAccumulator > 0 ? -1 : 1,
                    workspaces.length
                )
                if (next !== null)
                    MangoState.dispatchWorkspace(next, root.screen?.name ?? "")
            } else {
                const workspaces = root.protocolWindowsets
                const current = workspaces.findIndex(w => w.active)
                const next = current + (root.wheelAccumulator > 0 ? -1 : 1)
                if (current >= 0 && next >= 0 && next < workspaces.length
                    && workspaces[next].canActivate)
                    workspaces[next].activate()
            }
            root.wheelAccumulator = 0
            root.wheelGestureLocked = true
            wheelUnlock.restart()
        }
    }
}
