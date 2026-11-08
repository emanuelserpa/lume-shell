pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.WindowManager
import qs.services
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

    // Hyprland keeps its native model for occupancy and stable numeric IDs.
    // Other compositors share Quickshell's ext-workspace-v1 model.
    readonly property string compositor: CompositorState.sessionKind
    readonly property bool hyprlandActive: CompositorState.hyprlandNativeEnabled
    readonly property bool mangoActive:
        CompositorState.mangoCompatibilityEnabled && MangoState.available

    // qmllint disable unresolved-type
    readonly property var protocolWindowsets:
        WorkspaceModel.visibleWindowsets(
            root.screen ? WindowManager.screenProjection(root.screen).windowsets : [],
            root.compositor === "mango"
        )
    // qmllint enable unresolved-type
    readonly property bool protocolWorkspacesAvailable: root.protocolWindowsets.length > 0

    readonly property var mangoVisibleWorkspaces: MangoState.visibleTags(root.screen?.name ?? "")

    readonly property var visibleWorkspaces:
        root.hyprlandActive ? Hyprland.workspaces
        : root.protocolWorkspacesAvailable ? root.protocolWindowsets
        : root.mangoActive ? root.mangoVisibleWorkspaces : []

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

    Timer {
        id: workspaceRefresh
        interval: 50
        repeat: false
        onTriggered: Hyprland.refreshWorkspaces()
    }

    Connections {
        target: root.hyprlandActive ? Hyprland : null

        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow"
                    || event.name === "movewindowv2")
                workspaceRefresh.restart()
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
                required property int index
                readonly property bool belongsToScreen: {
                    if (!root.hyprlandActive)
                        return true

                    const monitor = root.screen ? Hyprland.monitorFor(root.screen) : null
                    const monitorName = String(monitor?.name ?? root.screen?.name ?? "")
                    const workspaceMonitor = String(modelData?.monitor?.name ?? "")
                    return !monitorName || !workspaceMonitor || workspaceMonitor === monitorName
                }
                property var ws: modelData
                property int workspaceIndex: index
                property bool active: root.hyprlandActive
                    ? ws !== null && ws.active
                    : ws !== null ? ws.active : false
                property bool urgent: ws !== null ? ws.urgent : false

                visible: root.hyprlandActive
                    ? (belongsToScreen
                        && !String(ws?.name ?? "").startsWith("special:")
                        && (active || WorkspaceModel.hasHyprlandWindows(ws)))
                    : true

                width: Math.max(root.theme.barWorkspaceMinWidth,
                                label.implicitWidth + root.theme.barWorkspaceHorizontalPadding)
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
                    anchors.fill: parent
                    anchors.topMargin: -1
                    anchors.bottomMargin: 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    renderType: Text.NativeRendering
                    text: String(parent.ws?.name ?? parent.ws?.id ?? (parent.workspaceIndex + 1))
                    color: parent.urgent ? root.theme.backgroundOpaque
                         : parent.active ? root.theme.primaryForeground
                         : hover.containsMouse ? root.theme.accent
                         : (root.theme.isLight ? root.theme.foreground : root.theme.offWhite)
                    font.family: root.theme.nerdFontFamily
                    font.pixelSize: root.theme.iconTokens.mdPlus
                    font.weight: Font.DemiBold
                    font.hintingPreference: Font.PreferFullHinting
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        // Hyprland display names can differ from workspace
                        // identity after `renameworkspace`; dispatch by the
                        // stable numeric ID when available.
                        if (root.hyprlandActive && parent.ws !== null) {
                            const id = WorkspaceModel.numericWorkspaceNumber(
                                parent.ws, { hyprland: true })
                            root.focusWorkspace(id > 0 ? id : parent.ws.name)
                        }
                        // ext-workspace-v1 is the shared activation path for
                        // Mango, labwc, Sway, niri, and compatible compositors.
                        else if (root.protocolWorkspacesAvailable && parent.ws !== null
                                && parent.ws.canActivate !== false
                                && typeof parent.ws.activate === "function")
                            parent.ws.activate()
                        else if (root.mangoActive) {
                            const tag = WorkspaceModel.numericWorkspaceNumber(
                                parent.ws, { mango: true })
                            if (tag > 0)
                                MangoState.dispatchWorkspace(tag, root.screen?.name ?? "")
                        }
                        else
                            root.focusWorkspace(String(parent.ws?.name ?? parent.ws?.id ?? ""))
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
                // Keep Hyprland's relative dispatch semantics and native order.
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
            }
            root.wheelAccumulator = 0
            root.wheelGestureLocked = true
            wheelUnlock.restart()
        }
    }
}
