pragma ComponentBehavior: Bound

import QtQuick
import qs.bar

Item {
    id: root

    required property var theme
    readonly property real contentScale: 1.22

    implicitWidth: island.implicitWidth
    implicitHeight: island.height

    Rectangle {
        id: island
        anchors.fill: parent
        implicitWidth: content.implicitWidth + 28
        height: 52
        radius: height / 2
        color: root.theme.glassPanelSurface
        border.width: 1
        border.color: root.theme.glassBorderSubtle

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: batteryPill.implicitWidth * root.contentScale
                height: root.theme.pillHeight * root.contentScale

                Battery {
                    id: batteryPill
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    transform: Scale {
                        origin.x: batteryPill.width / 2
                        origin.y: batteryPill.height / 2
                        xScale: root.contentScale
                        yScale: root.contentScale
                    }
                    theme: root.theme
                    plain: true
                }
            }

            Item {
                id: audioHitArea
                width: audioPill.implicitWidth * root.contentScale
                height: root.theme.pillHeight * root.contentScale

                Audio {
                    id: audioPill
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    transform: Scale {
                        origin.x: audioPill.width / 2
                        origin.y: audioPill.height / 2
                        xScale: root.contentScale
                        yScale: root.contentScale
                    }
                    theme: root.theme
                    plain: true
                    interactive: false
                    allowExternalSettings: false
                    popupTarget: audioHitArea
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            audioPill.openPopup()
                        } else if (mouse.button === Qt.RightButton && audioPill.sink?.audio) {
                            audioPill.sink.audio.muted = !audioPill.sink.audio.muted
                        }
                    }

                    onWheel: function(wheel) {
                        wheel.accepted = true
                        if (!audioPill.sink?.audio || audioPill.sink.audio.muted)
                            return
                        const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                        audioPill.sink.audio.volume = Math.max(0, Math.min(1.5,
                            audioPill.sink.audio.volume + delta))
                    }
                }
            }
        }
    }
}
