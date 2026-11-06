import QtQuick

Column {
    id: root

    required property var theme
    property real position: 0
    property real duration: 0
    property color accent: theme.accent
    property color timeColor: theme.surfaceVariantForeground
    property int trackHeight: 4
    property int hitAreaHeight: 12
    property int thumbSize: 0
    property int timePixelSize: theme.typeTokens.meta
    property int sectionSpacing: theme.spacingTokens.micro
    property bool seekEnabled: true

    signal seekRequested(real fraction)

    width: parent ? parent.width : implicitWidth
    spacing: sectionSpacing
    function clampedFraction(value) {
        if (root.duration <= 0 || !isFinite(root.position)) return 0
        return Math.max(0, Math.min(1, value / root.duration))
    }

    function timeText(seconds) {
        if (!isFinite(seconds) || seconds <= 0) return "0:00"
        const value = Math.floor(seconds)
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }

    function seekAt(x) {
        if (!root.seekEnabled || root.duration <= 0 || seekArea.width <= 0) return
        root.seekRequested(Math.max(0, Math.min(1, x / seekArea.width)))
    }

    Item {
        id: seekArea
        width: parent.width
        height: root.hitAreaHeight

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.trackHeight
            radius: height / 2
            color: root.theme.sliderTrack
            clip: true

            Rectangle {
                id: fill
                width: track.width * root.clampedFraction(root.position)
                height: track.height
                radius: track.radius
                color: root.accent

                Behavior on width {
                    enabled: root.theme.qmlAnimationsEnabled && !seekMouse.pressed
                    NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
                }
            }
        }

        Rectangle {
            visible: root.thumbSize > 0 && root.seekEnabled
                && (seekMouse.containsMouse || seekMouse.pressed)
            width: root.thumbSize
            height: root.thumbSize
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, fill.width - width / 2))
            color: root.theme.foreground
            opacity: 0.95
        }

        MouseArea {
            id: seekMouse
            anchors.fill: parent
            enabled: root.seekEnabled && root.duration > 0
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: function(mouse) { root.seekAt(mouse.x) }
            onPositionChanged: function(mouse) {
                if (pressed) root.seekAt(mouse.x)
            }
        }
    }

    Row {
        id: timeRow
        width: parent.width

        Text {
            id: elapsedLabel
            text: root.timeText(root.position)
            color: root.timeColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.timePixelSize
        }

        Item {
            width: Math.max(0, timeRow.width - elapsedLabel.implicitWidth - durationLabel.implicitWidth)
            height: 1
        }

        Text {
            id: durationLabel
            text: root.timeText(root.duration)
            color: root.timeColor
            font.family: root.theme.fontFamily
            font.pixelSize: root.timePixelSize
        }
    }
}
