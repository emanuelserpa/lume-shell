pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import "../services/NotificationContent.js" as NotificationContent

// shared-ui-guard: allow — persistent offscreen Canvas archiver for notification qsimage handles.
Item {
    id: root

    property bool active: false
    property bool autoRegister: true
    property var completionHandler: null
    property var currentJob: null
    property string activeSource: ""
    property bool imageLoadedInCanvas: false
    readonly property bool busy: root.currentJob !== null

    width: 256
    height: 256
    visible: false

    Component.onCompleted: {
        if (root.autoRegister)
            NotificationState.registerImageArchiver(root, root.active)
    }

    onActiveChanged: {
        if (root.autoRegister)
            NotificationState.registerImageArchiver(root, root.active)
    }

    Component.onDestruction: {
        timeoutTimer.stop()
        const src = root.activeSource
        root.currentJob = null
        root.activeSource = ""
        root.imageLoadedInCanvas = false
        if (src)
            archiveCanvas.unloadImage(src)
        if (root.autoRegister)
            NotificationState.unregisterImageArchiver(root)
    }

    function startJob(job) {
        if (!job || !job.source || !job.imagePath || root.currentJob !== null)
            return false

        root.currentJob = job
        root.imageLoadedInCanvas = false
        root.activeSource = String(job.source)
        timeoutTimer.restart()
        archiveCanvas.loadImage(root.activeSource)
        if (archiveCanvas.isImageError(root.activeSource)) {
            root.finishCurrent(false)
            return true
        }
        if (archiveCanvas.isImageLoaded(root.activeSource)) {
            root.imageLoadedInCanvas = true
            root.tryPaint()
        }
        return true
    }

    function tryPaint() {
        const job = root.currentJob
        const src = root.activeSource
        if (!job || !src)
            return
        if (probeImage.status === Image.Error || archiveCanvas.isImageError(src)) {
            root.finishCurrent(false)
            return
        }
        if (root.imageLoadedInCanvas && probeImage.status === Image.Ready)
            archiveCanvas.requestPaint()
    }

    function finishCurrent(saved) {
        const job = root.currentJob
        if (!job)
            return
        const src = root.activeSource
        timeoutTimer.stop()
        root.currentJob = null
        root.activeSource = ""
        root.imageLoadedInCanvas = false
        if (src)
            archiveCanvas.unloadImage(src)

        const handler = root.completionHandler
        const ok = Boolean(saved)
        Qt.callLater(function() {
            if (typeof handler === "function")
                handler(job, ok)
            else
                NotificationState.completeImageArchive(job, ok)
        })
    }

    Timer {
        id: timeoutTimer
        interval: 4000
        repeat: false
        onTriggered: root.finishCurrent(false)
    }

    Image {
        id: probeImage
        visible: false
        asynchronous: true
        cache: false
        source: root.activeSource
        onStatusChanged: root.tryPaint()
    }

    Canvas {
        id: archiveCanvas
        visible: false
        width: 256
        height: 256
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onImageLoaded: {
            const src = root.activeSource
            if (!src)
                return
            if (archiveCanvas.isImageError(src)) {
                root.finishCurrent(false)
                return
            }
            if (archiveCanvas.isImageLoaded(src)) {
                root.imageLoadedInCanvas = true
                root.tryPaint()
            }
        }

        onPaint: {
            const job = root.currentJob
            const src = root.activeSource
            if (!job || !src || !root.imageLoadedInCanvas || probeImage.status !== Image.Ready)
                return

            const crop = NotificationContent.squareCropRect(
                probeImage.implicitWidth, probeImage.implicitHeight)
            if (!crop) {
                root.finishCurrent(false)
                return
            }

            const ctx = archiveCanvas.getContext("2d")
            ctx.clearRect(0, 0, archiveCanvas.width, archiveCanvas.height)
            ctx.drawImage(src, crop.sx, crop.sy, crop.sw, crop.sh,
                          0, 0, archiveCanvas.width, archiveCanvas.height)
            const saved = Boolean(archiveCanvas.save(job.imagePath))
            root.finishCurrent(saved)
        }
    }
}
