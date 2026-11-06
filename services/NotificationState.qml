pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "NotificationContent.js" as NotificationContent

QtObject {
    id: root

    property bool dnd: false
    property var timestamps: ({})
    property var restoreHistory: []
    property int restoreIndex: -1
    property int restoreToastSerial: 0
    property var pendingDismissals: []
    property int dismissCursor: 0
    property var pendingGroupDismissals: []
    property int groupDismissCursor: 0
    property var internalNotifications: []
    property var persistentHistory: []
    property var retainedImageNotifications: []
    property var cachedNotificationImages: ({})
    property var capturingNotificationImages: ({})
    property int notificationImageSerial: 0
    property var pendingStoreRequests: []
    property bool notificationStoreStarted: false
    property int internalNotificationSerial: 0
    property string expiringInternalNotificationId: ""
    property string _lastFingerprint: ""
    property double _lastSeenTime: 0

    readonly property var server: notificationServer
    readonly property var tracked: {
        // The model is non-nullable; values is exposed at runtime despite incomplete metadata.
        // qmllint disable missing-property
        const raw = notificationServer.trackedNotifications.values
        // qmllint enable missing-property
        const live = raw ? raw.concat(root.internalNotifications) : root.internalNotifications.slice()
        const validLive = []
        const liveFingerprints = Object.create(null)
        for (let i = 0; i < live.length; i++) {
            const n = live[i]
            if (n && n.tracked !== false && root.notificationHasUsefulContent(n) && !root.isExcludedFromHistory(n)) {
                validLive.push(n)
                const fingerprint = root.notificationFingerprint(n)
                liveFingerprints[fingerprint] = (liveFingerprints[fingerprint] || 0) + 1
            }
        }

        // The database also contains current notifications. Hide one newest
        // stored copy per live notification, while retaining older identical
        // messages that should remain in history after the live one is cleared.
        const archived = []
        for (const n of root.persistentHistory || []) {
            if (!n || !root.notificationHasUsefulContent(n) || root.isExcludedFromHistory(n)) continue
            const fingerprint = root.notificationFingerprint(n)
            if ((liveFingerprints[fingerprint] || 0) > 0) {
                liveFingerprints[fingerprint] -= 1
                continue
            }
            archived.push(n)
        }

        const combined = validLive.concat(archived)
        combined.sort(function(a, b) {
            const timeA = Number(root.timestamps[a.id] ?? a.receivedAt ?? 0)
            const timeB = Number(root.timestamps[b.id] ?? b.receivedAt ?? 0)
            return timeB - timeA
        })
        return combined
    }
    readonly property int count: tracked ? tracked.length : 0
    readonly property bool hasCritical: {
        const list = tracked
        if (!list || list.length === 0) return false
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].urgency === NotificationUrgency.Critical) {
                return true
            }
        }
        return false
    }

    signal notificationReceived(var notification)
    signal notificationRestored(var notification)
    signal togglePopupRequested()
    signal batteryAlertsDismissed()

    function toggleDnd() {
        dnd = !dnd
    }

    function getFormattedTime(notificationId, fallbackTimestamp) {
        if (!notificationId) return "agora"
        const ts = timestamps[notificationId] || Number(fallbackTimestamp || 0)
        if (!ts) return "agora"
        const diffSecs = Math.floor((Date.now() - ts) / 1000)
        if (diffSecs < 60) return "agora"
        const diffMins = Math.floor(diffSecs / 60)
        if (diffMins < 60) return diffMins + "m"
        const diffHours = Math.floor(diffMins / 60)
        if (diffHours < 24) return diffHours + "h"
        return Math.floor(diffHours / 24) + "d"
    }

    function formatText(str) {
        return NotificationContent.formatText(str)
    }

    function clearAll() {
        restoreHistory = []
        restoreIndex = -1
        persistentHistory = []
        root.sendStoreRequest({"op": "clear"})
        // qmllint disable missing-property
        const native = notificationServer.trackedNotifications.values ?? []
        // qmllint enable missing-property
        pendingDismissals = native.concat(root.internalNotifications)
        dismissCursor = 0
        pendingGroupDismissals = []
        groupDismissCursor = 0
        timestamps = ({})
        if (pendingDismissals.length > 0) dismissTimer.start()
    }

    property Timer dismissTimer: Timer {
        id: dismissTimer
        interval: 16
        repeat: true
        onTriggered: {
            const batchSize = 5
            const end = Math.min(root.dismissCursor + batchSize, root.pendingDismissals.length)
            for (; root.dismissCursor < end; root.dismissCursor++) {
                root.dismiss(root.pendingDismissals[root.dismissCursor])
            }

            const groupEnd = Math.min(root.groupDismissCursor + 2,
                root.pendingGroupDismissals.length)
            for (; root.groupDismissCursor < groupEnd; root.groupDismissCursor++)
                root.dismiss(root.pendingGroupDismissals[root.groupDismissCursor])

            const clearDone = root.dismissCursor >= root.pendingDismissals.length
            const groupsDone = root.groupDismissCursor >= root.pendingGroupDismissals.length
            if (clearDone && groupsDone) {
                stop()
                root.pendingDismissals = []
                root.dismissCursor = 0
                root.pendingGroupDismissals = []
                root.groupDismissCursor = 0
            }
        }
    }

    function snapshotNotification(n) {
        const actions = []
        for (let i = 0; i < (n.actions.length ?? 0); i++) {
            const action = n.actions[i]
            actions.push({
                text: String(action?.text ?? "Ação"),
                identifier: String(action?.identifier ?? ""),
                invoke: typeof action?.invoke === "function"
                    ? function() { action.invoke() } : undefined
            })
        }

        return {
            id: "restore-" + (++root.restoreToastSerial),
            originalId: n.id,
            appName: String(n.appName ?? "Notificação"),
            appIcon: String(n.appIcon ?? ""),
            image: root.imageSource(n),
            hints: n.hints ?? ({}),
            summary: String(n.summary ?? ""),
            body: String(n.body ?? ""),
            urgency: n.urgency,
            actions: actions,
            tracked: false,
            receivedAt: Date.now()
        }
    }

    function sendStoreRequest(request) {
        if (!root.notificationStoreStarted) {
            const pending = root.pendingStoreRequests.slice()
            pending.push(request)
            root.pendingStoreRequests = pending
            return
        }
        notificationStoreProcess.write(JSON.stringify(request) + "\n")
    }

    function handleStoreResponse(line) {
        try {
            const response = JSON.parse(String(line).trim())
            if (response.type === "loaded") {
                root.persistentHistory = response.items || []
            } else if (response.type === "stored" && response.inserted && response.item) {
                const current = root.persistentHistory.slice()
                const id = String(response.item.id)
                if (!current.some(function(item) { return String(item.id) === id })) {
                    current.unshift(response.item)
                    current.length = Math.min(current.length, 500)
                    root.persistentHistory = current
                }
            } else if (response.type === "image-updated" && response.updated && response.item) {
                root.persistentHistory = root.persistentHistory.map(function(item) {
                    return String(item.id) === String(response.item.id)
                        ? response.item : item
                })
            } else if (response.type === "cleared") {
                root.persistentHistory = []
            } else if (response.type === "deleted" && response.id) {
                const deletedId = String(response.id)
                root.persistentHistory = root.persistentHistory.filter(function(item) {
                    return String(item.id) !== deletedId
                })
            } else if (response.type === "error") {
                console.warn("NotificationState: erro no histórico persistente:", response.error)
            }
        } catch (error) {
            console.warn("NotificationState: resposta inválida do histórico:", error)
        }
    }

    function restorePrevious() {
        if (root.restoreHistory.length === 0) return false

        const nextIndex = root.restoreIndex + 1
        if (nextIndex >= root.restoreHistory.length) return false

        root.restoreIndex = nextIndex
        root.notificationRestored(root.restoreHistory[nextIndex])
        return true
    }

    function dismiss(notification) {
        if (notification && typeof notification.dismiss === "function") {
            notification.dismiss()
        }
    }

    function dismissFromHistory(notification) {
        if (!notification) return
        if (notification.archived) {
            const archiveId = String(notification.id)
            root.persistentHistory = root.persistentHistory.filter(function(item) {
                return String(item.id) !== archiveId
            })
            root.sendStoreRequest({"op": "delete", "id": archiveId})
            return
        }

        const receivedAt = Number(root.timestamps[notification.id]
            ?? notification.receivedAt ?? Date.now())
        const snapshot = NotificationContent.storageSnapshot(notification, receivedAt)
        snapshot.image = root.imageSource(notification)
        const fingerprint = root.notificationFingerprint(notification)
        const current = root.persistentHistory.slice()
        let bestIndex = -1
        let bestDistance = Infinity
        for (let i = 0; i < current.length; i++) {
            if (root.notificationFingerprint(current[i]) !== fingerprint) continue
            const distance = Math.abs(Number(current[i].receivedAt || 0) - receivedAt)
            if (distance < bestDistance) {
                bestIndex = i
                bestDistance = distance
            }
        }
        if (bestIndex >= 0) current.splice(bestIndex, 1)
        root.persistentHistory = current
        root.sendStoreRequest({"op": "delete", "notification": snapshot})
        root.dismiss(notification)
    }

    function dismissGroup(groupKey) {
        if (!groupKey) return
        const tracked = root.tracked.filter(function(notification) {
            return NotificationContent.notificationGroupKey(notification) === groupKey
        })
        const pending = root.pendingGroupDismissals.slice()
        for (const notification of tracked) {
            if (!notification.archived
                    && !pending.some(function(item) {
                        return String(item.id) === String(notification.id)
                    }))
                pending.push(notification)
        }

        // Remove the whole visible app group in one model update and one SQLite
        // transaction. Native dismiss calls are spread across timer ticks.
        root.persistentHistory = root.persistentHistory.filter(function(notification) {
            return NotificationContent.notificationGroupKey(notification) !== groupKey
        })
        root.sendStoreRequest({"op": "delete_group", "groupKey": groupKey})
        root.pendingGroupDismissals = pending
        if (!dismissTimer.running) dismissTimer.start()
    }

    function dismissInternalNotification(notificationId) {
        const current = root.internalNotifications
        const remaining = current.filter(function(notification) {
            return notification.internalNotificationId !== notificationId
        })
        if (remaining.length === current.length) return
        root.internalNotifications = remaining
        if (root.expiringInternalNotificationId === notificationId) {
            root.expiringInternalNotificationId = ""
            internalExpiryTimer.stop()
        }
    }

    function postInternalNotification(details) {
        if (!details || !root.notificationHasUsefulContent(details)) return null

        const key = String(details.replaceKey ?? "")
        const notificationId = "internal-" + (++root.internalNotificationSerial)
        const isBat = root.isBattery(details)
        const notification = {
            id: notificationId,
            internalNotificationId: notificationId,
            appName: String(details.appName ?? "Quickshell"),
            appIcon: String(details.appIcon ?? ""),
            image: String(details.image ?? ""),
            hints: ({}),
            summary: String(details.summary ?? ""),
            body: String(details.body ?? ""),
            urgency: details.urgency ?? NotificationUrgency.Normal,
            actions: [],
            tracked: isBat ? false : true,
            replaceKey: key,
            dismiss: function() { root.dismissInternalNotification(notificationId) }
        }

        const current = root.internalNotifications
        const remaining = key
            ? current.filter(function(item) { return item.replaceKey !== key })
            : current.slice()
        remaining.push(notification)
        root.internalNotifications = remaining
        if (!isBat) {
            root.recordNotification(notification)
        }

        const expireAfterMs = Number(details.expireAfterMs ?? 0)
        if (expireAfterMs > 0) {
            root.expiringInternalNotificationId = notificationId
            internalExpiryTimer.interval = expireAfterMs
            internalExpiryTimer.restart()
        }

        if (!root.dnd || notification.urgency === NotificationUrgency.Critical)
            root.notificationReceived(notification)
        return notification
    }

    function recordNotification(notification) {
        if (!notification || root.isExcludedFromHistory(notification)) return

        const history = root.restoreHistory.slice()
        history.unshift(root.snapshotNotification(notification))
        if (history.length > 20) history.length = 20
        root.restoreHistory = history
        root.restoreIndex = -1

        const updated = Object.assign({}, root.timestamps)
        const receivedAt = Date.now()
        updated[notification.id] = receivedAt
        root.timestamps = updated

        root.sendStoreRequest({
            "op": "append",
            "notification": NotificationContent.storageSnapshot(notification, receivedAt)
        })
    }

    property Process notificationStoreProcess: Process {
        id: notificationStoreProcess
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/notification_store.py"]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: function(line) { root.handleStoreResponse(line) }
        }

        stderr: SplitParser {
            onRead: function(line) { console.warn("notification_store:", line) }
        }

        onStarted: {
            root.notificationStoreStarted = true
            const pending = root.pendingStoreRequests
            root.pendingStoreRequests = []
            root.notificationStoreProcess.write(JSON.stringify({"op": "load", "limit": 500}) + "\n")
            for (const request of pending)
                root.notificationStoreProcess.write(JSON.stringify(request) + "\n")
        }

        onExited: {
            root.notificationStoreStarted = false
            storeRestartTimer.restart()
        }
    }

    property Timer storeRestartTimer: Timer {
        id: storeRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.notificationStoreProcess.running)
                root.notificationStoreProcess.running = true
        }
    }

    property Timer internalExpiryTimer: Timer {
        interval: 2500
        repeat: false
        onTriggered: {
            const notificationId = root.expiringInternalNotificationId
            root.expiringInternalNotificationId = ""
            if (notificationId) root.dismissInternalNotification(notificationId)
        }
    }

    function isBattery(n) {
        return NotificationContent.isBattery(n)
    }

    function isExcludedFromHistory(n) {
        return NotificationContent.isExcludedFromHistory(n)
    }

    function isBatteryAlert(n) {
        return NotificationContent.isBatteryAlert(n)
    }

    function batteryIcon(n) {
        return NotificationContent.batteryIcon(n)
    }

    function isCharging(n) {
        return NotificationContent.isChargingNotification(n)
    }

    function isCriticalBattery(n) {
        return NotificationContent.isCriticalNotification(n)
    }

    function batteryColor(n, theme) {
        if (!n || !theme) return theme?.foreground ?? theme?.offWhite ?? "white"
        if (root.isCharging(n)) {
            return theme.green
        }
        if (root.isCriticalBattery(n)) {
            return theme.red
        }
        return theme.yellow
    }

    // Dismiss stale low/critical battery alerts once power is connected.
    // Sender-agnostic: matches any tracked notification about battery,
    // regardless of which daemon/app emitted it.
    function dismissBatteryAlerts() {
        const list = root.tracked.slice()
        for (let i = 0; i < list.length; i++) {
            if (root.isBatteryAlert(list[i])) {
                root.dismiss(list[i])
            }
        }
        root.batteryAlertsDismissed()
    }

    function primaryAction(notification) {
        const actions = notification?.actions
        if (!actions || actions.length === 0) return null

        for (let i = 0; i < actions.length; i++) {
            if (String(actions[i]?.identifier ?? "").toLowerCase() === "default")
                return actions[i]
        }

        for (let i = 0; i < actions.length; i++) {
            const action = actions[i]
            if (/^(open|abrir)$/i.test(String(action?.text ?? "").trim())
                    || String(action?.identifier ?? "").toLowerCase() === "open")
                return action
        }

        return null
    }

    function invokePrimaryAction(notification) {
        const action = primaryAction(notification)
        if (action && typeof action.invoke === "function") {
            action.invoke()
            return true
        }

        // Archived notifications no longer have a live D-Bus action callback.
        // Use the desktop-entry ID saved with the notification to reopen its app.
        let desktopEntry = String(notification?.desktopEntry
                                  || notification?.hints?.["desktop-entry"]
                                  || "").trim()
        if (desktopEntry.endsWith(".desktop"))
            desktopEntry = desktopEntry.slice(0, -8)
        if (!/^[A-Za-z0-9._-]+$/.test(desktopEntry)) return false

        Quickshell.execDetached(["gtk-launch", desktopEntry])
        return true
    }

    function resolveIcon(notification) {
        if (!notification || root.isBattery(notification)) return ""
        let name = notification.appIcon
        if (!name && notification.image && notification.image.startsWith("image://icon/"))
            name = notification.image.substring(13)
        if (!name && notification.hints)
            name = notification.hints["image-path"] || notification.hints["image_path"]
        if (name && typeof name === "string") {
            if (name.toLowerCase().indexOf("battery") !== -1) return ""
            if (name.startsWith("/") || name.startsWith("file://")) return name
            return Quickshell.iconPath(name, "")
        }
        if (notification.image
                && (notification.image.startsWith("/") || notification.image.startsWith("file://")))
            return notification.image
        return ""
    }

    function isPlaceholderLabel(str) {
        return NotificationContent.isPlaceholderLabel(str)
    }

    function hasRealImage(n) {
        return NotificationContent.hasRealImage(n)
    }

    function hasUsefulAction(actions) {
        return NotificationContent.hasUsefulAction(actions)
    }

    function notificationHasUsefulContent(n) {
        return NotificationContent.hasUsefulContent(n)
    }

    function notificationFingerprint(n) {
        return String(n?.appName ?? "").trim() + "\n"
            + root.formatText(n?.summary) + "\n"
            + root.formatText(n?.body) + "\n"
            + root.imageSource(n)
    }

    function imageSource(notification) {
        const source = String(notification?.image ?? "")
        return String(root.cachedNotificationImages[source] ?? source)
    }

    function retainNotificationImage(notification) {
        const source = String(notification?.image ?? "")
        if (!source.startsWith("image://qsimage/")) return
        if (root.retainedImageNotifications.some(function(item) {
            return item.notification === notification
        })) return

        const retained = root.retainedImageNotifications.slice()
        retained.push({ notification: notification, source: source })
        if (retained.length > 500) retained.shift()
        root.retainedImageNotifications = retained
    }

    function releaseNotificationImage(notification) {
        root.retainedImageNotifications = root.retainedImageNotifications.filter(
            function(item) { return item.notification !== notification })
    }

    function archiveNotificationImage(notification, imageItem) {
        const source = String(notification?.image ?? "")
        if (!source.startsWith("image://qsimage/")
                || root.cachedNotificationImages[source]
                || root.capturingNotificationImages[source]
                || !imageItem
                || (imageItem.status !== undefined && imageItem.status !== Image.Ready)) return false

        root.retainNotificationImage(notification)
        const dataHome = Quickshell.env("XDG_DATA_HOME")
                       || (Quickshell.env("HOME") + "/.local/share")
        const receivedAt = Number(root.timestamps[notification.id]
            ?? notification.receivedAt ?? Date.now())
        const serial = ++root.notificationImageSerial
        const imagePath = dataHome + "/quickshell/notifications/images/notification-"
                        + receivedAt + "-" + serial + ".png"
        const capturing = Object.assign({}, root.capturingNotificationImages)
        capturing[source] = true
        root.capturingNotificationImages = capturing
        const started = imageItem.grabToImage(function(result) {
            const saved = Boolean(result && result.saveToFile(imagePath))
            const currentCaptures = Object.assign({}, root.capturingNotificationImages)
            delete currentCaptures[source]
            root.capturingNotificationImages = currentCaptures
            if (!saved) {
                console.warn("NotificationState: não foi possível arquivar imagem", source)
                return
            }

            const updatedImages = Object.assign({}, root.cachedNotificationImages)
            updatedImages[source] = imagePath
            root.cachedNotificationImages = updatedImages
            root.releaseNotificationImage(notification)

            const snapshot = NotificationContent.storageSnapshot(notification, receivedAt)
            snapshot.sourceImage = source
            snapshot.image = imagePath
            root.sendStoreRequest({"op": "update_image", "notification": snapshot})

            root.restoreHistory = root.restoreHistory.map(function(item) {
                return item.originalId === notification.id && item.image === source
                    ? Object.assign({}, item, { image: imagePath }) : item
            })
        }, Qt.size(256, 256))
        if (!started) {
            const currentCaptures = Object.assign({}, root.capturingNotificationImages)
            delete currentCaptures[source]
            root.capturingNotificationImages = currentCaptures
        }
        return Boolean(started)
    }

    property IpcHandler ipc: IpcHandler {
        target: "notifications"

        function toggle() {
            root.togglePopupRequested()
        }

        function toggleDnd() {
            root.toggleDnd()
        }

        function clear() {
            root.clearAll()
        }

        function restorePrevious() {
            root.restorePrevious()
        }
    }

    property NotificationServer notificationServer: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: function(n) {
            if (!n) return

            if (!root.notificationHasUsefulContent(n)) {
                // qmllint disable unresolved-type
                // Notification actions are a QList exposed as a JS array at runtime.
                // qmllint disable missing-property
                console.log("NotificationState: discarded empty notification app=<" + String(n.appName ?? "") + "> summary_length=" + root.formatText(n.summary).length + " body_length=" + root.formatText(n.body).length + " actions=" + (n.actions ? n.actions.length : 0) + " id=" + n.id)
                // qmllint enable missing-property
                // qmllint enable unresolved-type
                n.tracked = false
                if (typeof n.dismiss === "function") {
                    n.dismiss()
                }
                return
            }

            const fp = root.notificationFingerprint(n)
            const now = Date.now()
            if (fp === root._lastFingerprint && (now - root._lastSeenTime) < 2000) {
                console.log("NotificationState: discarded duplicate notification id=" + n.id)
                n.tracked = false
                if (typeof n.dismiss === "function") {
                    n.dismiss()
                }
                return
            }

            const excludedFromHistory = root.isExcludedFromHistory(n)
            n.tracked = !excludedFromHistory
            if (!excludedFromHistory) {
                root.retainNotificationImage(n)
                root.recordNotification(n)
            }
            root._lastFingerprint = fp
            root._lastSeenTime = now

            const isCritical = n.urgency === NotificationUrgency.Critical
            if (!root.dnd || isCritical) {
                root.notificationReceived(n)
            }
        }
    }
}
