import QtQuick

// Shared kinetic wheel scrolling for popups and lists.
//
// Contract:
// - Mouse wheels (angleDelta notches) use direct steps in the conventional
//   direction, with one shared scale across scrollable surfaces.
// - Touchpads (high-frequency pixelDelta) track 1:1 and glide with momentum
//   on release, estimated over the last 150 ms of the gesture.
// - Views with nothing to scroll ignore the event (no accept), so outer
//   handlers keep working.
//
// Usage:
//   WheelKinetic { scrollTarget: myFlickable }
//   WheelKinetic { scrollTarget: myFlickable; scrollOrientation: Qt.Horizontal }
WheelHandler {
    id: root

    required property Flickable scrollTarget
    property int scrollOrientation: Qt.Vertical
    orientation: root.scrollOrientation

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    property var samples: []

    // A Timer cannot be nested inside a handler (handlers are plain
    // QObjects with no default property), so it is created dynamically
    // parented to the target view, which is a real Item.
    property Timer coastTimer: null

    Component.onCompleted: {
        try {
            root.coastTimer = Qt.createQmlObject(
                "import QtQuick; Timer { interval: 80; repeat: false }",
                root.scrollTarget)
            root.coastTimer.triggered.connect(root.coast)
            root.coastTimer.interval = 80
        } catch (e) {
            console.log("WheelKinetic: coast timer unavailable, gliding off (" + e + ")")
        }
    }

    function isVertical() {
        return root.scrollOrientation === Qt.Vertical
    }

    function maxScroll() {
        const f = root.scrollTarget
        if (!f)
            return 0
        return Math.max(0, root.isVertical() ? f.contentHeight - f.height : f.contentWidth - f.width)
    }

    function pos() {
        const f = root.scrollTarget
        return root.isVertical() ? f.contentY : f.contentX
    }

    function setPos(v) {
        const f = root.scrollTarget
        if (!f)
            return
        if (root.isVertical())
            f.contentY = v
        else
            f.contentX = v
    }

    function primaryPixel(event) {
        if (root.isVertical())
            return event.pixelDelta.y
        return Math.abs(event.pixelDelta.y) >= Math.abs(event.pixelDelta.x)
            ? event.pixelDelta.y : event.pixelDelta.x
    }

    function primaryAngle(event) {
        if (root.isVertical())
            return event.angleDelta.y
        return Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
            ? event.angleDelta.y : event.angleDelta.x
    }

    function handle(event) {
        if (!root.scrollTarget || root.maxScroll() <= 0)
            return
        const px = root.primaryPixel(event)
        if (px !== 0) {
            const step = -px
            root.setPos(Math.max(0, Math.min(root.maxScroll(), root.pos() + step)))
            const now = Date.now()
            root.samples.push({ t: now, d: step })
            while (root.samples.length > 0 && now - root.samples[0].t > 150)
                root.samples.shift()
            if (root.coastTimer)
                root.coastTimer.restart()
        } else {
            const ang = root.primaryAngle(event)
            if (ang === 0)
                return
            root.setPos(Math.max(0, Math.min(root.maxScroll(), root.pos() - ang)))
        }
        event.accepted = true
    }

    function coast() {
        if (root.samples.length === 0 || !root.scrollTarget)
            return
        let total = 0
        for (let i = 0; i < root.samples.length; i++)
            total += root.samples[i].d
        // The idle delay detects release and remains part of the velocity window.
        const span = Math.max(16, Date.now() - root.samples[0].t)
        root.samples = []
        const v = Math.max(-6000, Math.min(6000, total / span * 1000))
        if (Math.abs(v) <= 250)
            return
        // flick() moves the content opposite to content position.
        if (root.isVertical())
            root.scrollTarget.flick(0, -v)
        else
            root.scrollTarget.flick(-v, 0)
    }

    onWheel: function(event) {
        root.handle(event)
    }
}
