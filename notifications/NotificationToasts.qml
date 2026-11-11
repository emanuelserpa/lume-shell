pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../services/NotificationContent.js" as NotificationContent

// qmllint disable uncreatable-type
PanelWindow {
    // The compositor plugin provides the concrete PanelWindow implementation.
    // qmllint enable uncreatable-type
    id: root

    anchors {
        top: true
        right: true
    }

    // QMargins is valid at runtime; the shipped qmllint metadata cannot
    // resolve its grouped top/right members.
    // qmllint disable unqualified unresolved-type
    margins.top: 45
    margins.right: root.theme.barPanelInset + root.theme.spacingTokens.md
    // qmllint enable unqualified unresolved-type
    readonly property real swipeRunway: 160
    implicitWidth: root.theme.popupWidths.large + root.swipeRunway
    implicitHeight: Math.max(1, toastColumn.implicitHeight)

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    color: "transparent"
    surfaceFormat.opaque: false
    readonly property bool fullscreenActive: Boolean(ToplevelManager.activeToplevel?.fullscreen)
    readonly property var visibleToasts: NotificationContent.visibleToastItems(
        root.activeToasts,
        root.fullscreenActive,
        NotificationUrgency.Critical
    )
    visible: root.visibleToasts.length > 0

    readonly property var theme: Theme {}

    property var activeToasts: []

    // Keep delegate identity stable when a new notification arrives. The array
    // owns native notification objects; the model only stores stable keys.
    ListModel { id: toastModel }

    Timer {
        id: stackEntranceTimer
        interval: 16
        repeat: false
        onTriggered: {
            const ready = []
            for (let i = 0; i < root.activeToasts.length; i++) {
                const toast = root.activeToasts[i]
                ready.push(toast.entered ? toast : Object.assign({}, toast, {entered: true}))
            }
            root.activeToasts = ready
        }
    }

    Connections {
        target: NotificationState

        function onNotificationReceived(n) {
            root.addToast(n)
        }

        function onNotificationRestored(n) {
            root.addToast(n, true)
        }

        function onBatteryAlertsDismissed() {
            const remaining = NotificationContent.withoutBatteryAlertToasts(root.activeToasts)
            const remainingIds = remaining.map(toast => toast.id)
            const stale = root.activeToasts.filter(toast => remainingIds.indexOf(toast.id) === -1)
            for (let i = 0; i < stale.length; i++)
                root.closeToast(stale[i].id)
        }
    }

    function addToast(n, restored = false) {
        if (!n || !NotificationState.notificationHasUsefulContent(n)) return

        let timeout = 5500
        if (n.urgency === NotificationUrgency.Critical) {
            timeout = 0
        } else if (n.urgency === NotificationUrgency.Low) {
            timeout = 3500
        }

        const toastItem = {
            "id": n.id,
            "notification": n,
            "timeout": timeout,
            "created": Date.now(),
            "restored": restored,
            "entered": root.activeToasts.length === 0 || !root.theme.qmlAnimationsEnabled
        }

        const key = String(n.id)
        const existing = root.activeToasts.findIndex(t => String(t.id) === key)
        if (existing !== -1) {
            const wasEntered = root.activeToasts[existing].entered
            toastItem.entered = wasEntered === undefined ? true : Boolean(wasEntered)
            const updated = root.activeToasts.slice()
            updated[existing] = toastItem
            root.closingIds = root.closingIds.filter(id => String(id) !== key)
            root.activeToasts = updated
            return
        }

        // Evict only the oldest delegate; existing cards keep their timers,
        // images, hover and animation state during bursts.
        if (root.activeToasts.length >= 4)
            root.removeToast(root.activeToasts[root.activeToasts.length - 1].id)
        root.activeToasts = [toastItem].concat(root.activeToasts)
        toastModel.insert(0, {toastKey: key})
        if (!toastItem.entered)
            stackEntranceTimer.restart()
    }

    function removeToast(toastId) {
        const key = String(toastId)
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).toastKey === key) {
                toastModel.remove(i)
                break
            }
        }
        root.activeToasts = root.activeToasts.filter(t => String(t.id) !== key)
        root.closingIds = root.closingIds.filter(id => String(id) !== key)
    }

    // Close by fading out, then remove from the model without a height collapse.
    property var closingIds: []

    function closeToast(toastId) {
        if (root.closingIds.indexOf(toastId) !== -1) return
        const ids = root.closingIds.slice()
        ids.push(toastId)
        root.closingIds = ids
    }

    Column {
        id: toastColumn
        width: parent.width
        spacing: root.theme.spacingTokens.md

        // Existing cards move to their new slots immediately. Only the new
        // card animates, keeping the translucent stack from leaving trails.

        Repeater {
            model: toastModel

            delegate: Item {
                id: toastDelegate
                required property string toastKey
                readonly property var toastInfo: root.activeToasts.find(
                    t => String(t.id) === toastKey) ?? ({id: toastKey, notification: null, timeout: 0, created: 0, entered: false})

                readonly property var n: toastDelegate.toastInfo.notification
                readonly property bool isCritical: n && n.urgency === NotificationUrgency.Critical
                readonly property bool hasContent: NotificationState.notificationHasUsefulContent(n)
                width: parent.width
                implicitHeight: toastCard.height
                height: implicitHeight

                PopupCard {
                    id: toastCard
                    property real swipeOffset: 0
                    property real swipeDistance: 0
                    anchors.left: parent.left
                    anchors.leftMargin: root.swipeRunway + toastCard.swipeOffset
                    visible: toastDelegate.hasContent && (!root.fullscreenActive || toastDelegate.isCritical)
                    width: root.theme.popupWidths.large
                    scale: 1
                    popupOffset: 0
                    implicitHeight: toastDelegate.hasContent ? (toastContent.implicitHeight + root.theme.popupInsets.large * 2) : 0
                    height: implicitHeight
                    theme: root.theme
                    focus: false
                    cornerRadius: root.theme.radiusPopup
                    // Keep urgency in the existing red icon; the perimeter and
                    // surface match the bar's translucent glass.
                    cardColor: root.theme.barIslandSurface
                    frameColor: root.theme.barIslandBorder
                    opened: Boolean(toastDelegate.toastInfo.entered) && !dying

                    readonly property bool dying: root.closingIds.indexOf(toastDelegate.toastInfo.id) !== -1

                    onDyingChanged: {
                        if (dying) removeTimer.start()
                        else removeTimer.stop()
                    }

                    Timer {
                        id: removeTimer
                        interval: root.theme.qmlAnimationsEnabled ? root.theme.motionPopupExit : 0
                        repeat: false
                        onTriggered: root.removeToast(toastDelegate.toastInfo.id)
                    }

                    Timer {
                        id: dismissTimer
                        interval: toastDelegate.toastInfo?.timeout ?? 0
                        running: toastCard.visible && (toastDelegate.toastInfo?.timeout ?? 0) > 0 && !cardHover.hovered && !toastCard.dying
                        repeat: false
                        onTriggered: root.closeToast(toastDelegate.toastInfo.id)
                    }

                    readonly property double receivedAt: toastDelegate.toastInfo.created
                    onReceivedAtChanged: {
                        if (dismissTimer.running) dismissTimer.restart()
                    }

                    HoverHandler {
                        id: cardHover
                    }

                    DragHandler {
                        id: toastSwipe
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onActiveChanged: {
                            if (active) {
                                toastCard.swipeDistance = 0
                                toastReturnAnimation.stop()
                                toastDismissAnimation.stop()
                                return
                            }
                            const distance = toastCard.swipeDistance
                            if (distance <= -Math.max(72, toastCard.width * 0.28)) {
                                toastDismissAnimation.to = -root.swipeRunway - toastCard.width
                                toastDismissAnimation.start()
                            } else {
                                toastReturnAnimation.start()
                            }
                        }
                        onTranslationChanged: {
                            if (active) {
                                toastCard.swipeDistance = translation.x
                                toastCard.swipeOffset = Math.max(
                                    -root.swipeRunway, Math.min(0, translation.x))
                            }
                        }
                    }

                    NumberAnimation {
                        id: toastReturnAnimation
                        target: toastCard
                        property: "swipeOffset"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: toastDismissAnimation
                        target: toastCard
                        property: "swipeOffset"
                        duration: 150
                        easing.type: Easing.InCubic
                        onFinished: {
                            NotificationState.dismissFromHistory(toastDelegate.n)
                            root.closeToast(toastDelegate.toastInfo.id)
                        }
                    }

                    NotificationCardContent {
                        id: toastContent
                        theme: root.theme
                        notification: toastDelegate.n
                        expanded: cardHover.hovered
                        dismissible: true
                        dismissButtonAlwaysVisible: true
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.theme.popupInsets.large
                        onActivated: root.closeToast(toastDelegate.toastInfo.id)
                        onDismissRequested: {
                            NotificationState.dismissFromHistory(toastDelegate.n)
                            root.closeToast(toastDelegate.toastInfo.id)
                        }
                    }
                }
            }
        }
    }
}
