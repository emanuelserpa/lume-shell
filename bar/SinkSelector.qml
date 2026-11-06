// LEGADO: popup não montado no shell atual (substituído pelo mixer completo em bar/AudioPopup.qml).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var sinks: []
    property var selectedSink: null

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 320
    implicitHeight: Math.min(340, listColumn.implicitHeight + 12)

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    PopupCard {
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        ScrollableList {
            id: sinkList
            theme: root.theme
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.small
            contentSpacing: root.theme.spacingTokens.tiny
            showScrollBar: true

            Column {
                id: listColumn
                width: parent.width
                spacing: root.theme.spacingTokens.tiny

                Repeater {
                    model: root.sinks

                    delegate: PopupListRow {
                        id: sinkDelegate
                        theme: root.theme
                        required property var modelData
                        rowHeight: 42
                        cornerRadius: root.theme.radiusSm
                        active: modelData === root.selectedSink
                        idleColor: "transparent"
                        idleBorderWidth: 0
                        activeBorderWidth: 0
                        leadingIcon: modelData === root.selectedSink ? "󰓃" : "󰓄"
                        leadingIconColor: modelData === root.selectedSink
                            ? root.theme.primary
                            : root.theme.foreground
                        title: modelData.description
                            || modelData.nickname
                            || modelData.name
                            || "Output de áudio"
                        titlePixelSize: root.theme.typeTokens.bodyEmphasis
                        subtitle: modelData.name || ""
                        subtitleColor: root.theme.foreground

                        interactionHandlers: TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                Pipewire.preferredDefaultAudioSink = sinkDelegate.modelData
                                root.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
